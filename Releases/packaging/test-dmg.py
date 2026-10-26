"""macOS regression checks: permissions, release rollback, and owned mount cleanup."""

import contextlib
import io
import json
import os
from pathlib import Path
import plistlib
import signal
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import dmg


class PackagingTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="finder2right-dmg-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)

    def invalid_app(self):
        app = self.root / "Finder2right.app"
        main = app / "Contents/MacOS/Finder2right"
        main.parent.mkdir(parents=True)
        main.write_bytes(b"unchanged executable content")
        main.chmod(0o644)
        (app / "Contents/Info.plist").write_bytes(plistlib.dumps({"CFBundleExecutable": "Finder2right"}))
        return app

    def test_prepare_rejects_non_executable_main(self):
        self.invalid_app()
        with self.assertRaisesRegex(RuntimeError, "主程序没有执行权限"):
            dmg.prepare(self.root, self.root, "Finder2right-test-arm64.dmg")

    def test_verify_rejects_non_executable_main(self):
        app = self.invalid_app()
        (self.root / "Applications").symlink_to("/Applications")
        for name in dmg.HELPERS:
            (self.root / name).touch()
        manifest = self.root / ".manifest.json"
        manifest.write_text(json.dumps({"app": dmg.app_files(app)}))
        with self.assertRaisesRegex(RuntimeError, "主程序没有执行权限"):
            dmg.verify(self.root, manifest)

    def valid_app(self):
        app = self.invalid_app()
        main = app / "Contents/MacOS/Finder2right"
        main.write_bytes(bytes.fromhex("cffaedfe") + b"test binary")
        main.chmod(0o755)
        metadata = {
            "CFBundleExecutable": "Finder2right", "CFBundleIdentifier": "local.finder2right",
            "CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "1", "LSMinimumSystemVersion": "14.0",
        }
        (app / "Contents/Info.plist").write_bytes(plistlib.dumps(metadata))
        extension = app / "Contents/PlugIns/FinderExtension.appex"
        extension_main = extension / "Contents/MacOS/FinderExtension"
        extension_main.parent.mkdir(parents=True)
        extension_main.write_bytes(main.read_bytes())
        extension_main.chmod(0o755)
        metadata.update({
            "CFBundleExecutable": "FinderExtension",
            "CFBundleIdentifier": "local.finder2right.FinderExtension",
            "NSExtension": {"NSExtensionPointIdentifier": "com.apple.FinderSync"},
        })
        (extension / "Contents/Info.plist").write_bytes(plistlib.dumps(metadata))
        return app, extension

    def test_rejects_missing_finder_extension(self):
        app, extension = self.valid_app()
        extension.rename(extension.with_name("Missing.appex"))
        with self.assertRaisesRegex(RuntimeError, "缺少 FinderExtension"):
            dmg.executable_main(app)

    def test_rejects_mismatched_extension_version(self):
        app, extension = self.valid_app()
        path = extension / "Contents/Info.plist"
        metadata = plistlib.loads(path.read_bytes())
        metadata["CFBundleVersion"] = "2"
        path.write_bytes(plistlib.dumps(metadata))
        with self.assertRaisesRegex(RuntimeError, "CFBundleVersion 不一致"):
            dmg.executable_main(app)

    def test_rejects_universal_binary_before_signing(self):
        self.valid_app()
        with patch.object(dmg.subprocess, "check_output", return_value="arm64 x86_64"), \
                patch.object(dmg.subprocess, "run") as signing:
            with self.assertRaisesRegex(RuntimeError, "架构不符合要求"):
                dmg.prepare(self.root, self.root, "Finder2right-test-arm64.dmg")
            signing.assert_not_called()

    def test_quarantine_command_preserves_other_attributes_and_symlink_target(self):
        app = self.root / "Finder2right.app"
        app.mkdir()
        inside = app / "binary"
        outside = self.root / "outside"
        inside.touch()
        outside.touch()
        (app / "link").symlink_to(outside)
        for file in (app, inside, outside):
            subprocess.run(["/usr/bin/xattr", "-w", "com.apple.quarantine", "test", str(file)], check=True)
            subprocess.run(["/usr/bin/xattr", "-w", "test.keep", "retained", str(file)], check=True)
        helper = (Path(__file__).parent / "清除下载隔离.command").read_text()
        command = next(line.strip().removeprefix("elif sudo ").removesuffix("; then")
                       for line in helper.splitlines() if line.strip().startswith("elif sudo /usr/bin/xattr"))
        subprocess.run(["/bin/zsh", "-c", 'app="$1"\n' + command, "quarantine-test", str(app)], check=True)
        for file in (app, inside):
            attributes = subprocess.check_output(["/usr/bin/xattr", str(file)], text=True).splitlines()
            self.assertNotIn("com.apple.quarantine", attributes)
            self.assertEqual(dmg.attribute(file, "test.keep"), b"retained")
        self.assertEqual(dmg.attribute(outside, "com.apple.quarantine"), b"test")
        self.assertEqual(dmg.attribute(outside, "test.keep"), b"retained")

    def releases(self, existing=True):
        output = self.root / "Finder2right-test-arm64.dmg"
        guide = self.root / "安装指南.html"
        if existing:
            output.write_bytes(b"old image")
            guide.write_bytes(b"old guide")
            subprocess.run(["/usr/bin/xattr", "-wx", "com.apple.ResourceFork",
                            b"old metadata".hex(), str(guide)], check=True)
        image_source = self.root / "input.dmg"
        guide_source = self.root / "input.html"
        image_source.write_bytes(b"new image")
        guide_source.write_bytes(b"new guide")
        return image_source, guide_source, output, guide

    def test_locked_guide_leaves_both_old_files(self):
        image, source, output, guide = self.releases()
        os.chflags(guide, stat.UF_IMMUTABLE)
        try:
            with self.assertRaisesRegex(RuntimeError, "已锁定"):
                dmg.publish(image, source, output)
            self.assertEqual(output.read_bytes(), b"old image")
            self.assertEqual(guide.read_bytes(), b"old guide")
        finally:
            os.chflags(guide, 0)

    def rollback_check(self, existing=True, interrupt=False):
        image, source, output, guide = self.releases(existing)
        original_replace = os.replace

        def fail_second(old, new):
            if Path(old).name == "new-1":
                if interrupt:
                    os.kill(os.getpid(), signal.SIGTERM)
                raise PermissionError("injected second replacement failure")
            original_replace(old, new)

        with patch.object(dmg.os, "replace", side_effect=fail_second):
            with self.assertRaises((PermissionError, RuntimeError)):
                dmg.publish(image, source, output)
        if existing:
            self.assertEqual(output.read_bytes(), b"old image")
            self.assertEqual(guide.read_bytes(), b"old guide")
            self.assertEqual(dmg.attribute(guide, "com.apple.ResourceFork"), b"old metadata")
        else:
            self.assertFalse(output.exists())
            self.assertFalse(guide.exists())
        self.assertFalse(list(self.root.glob(".finder2right-publish-*")))

    def test_second_replace_failure_restores_data_and_metadata(self):
        self.rollback_check()

    def test_failed_first_release_removes_partial_output(self):
        self.rollback_check(existing=False)

    def test_termination_during_publish_rolls_back(self):
        self.rollback_check(interrupt=True)

    def mount_failure_check(self, parser_failure):
        resources = Path(__file__).resolve().parent
        entry = (resources.parent / "package-dmg.sh").read_text()
        cleanup = entry[entry.index("cleanup() {"):entry.index("trap 'cleanup $?' EXIT")]
        functions = entry[entry.index("attach_image() {"):entry.index("hdiutil create -srcfolder")]
        work = self.root / "work"
        work.mkdir()
        lock = self.root / "lock"
        lock.mkdir()
        image = work / "writable.dmg"
        subprocess.run(["hdiutil", "create", "-size", "8m", "-fs", "HFS+", "-volname",
                        "Finder2right regression", str(image)], check=True, capture_output=True)
        environment = os.environ.copy()
        if not parser_failure:
            shim = self.root / "bin"
            shim.mkdir()
            diskutil = shim / "diskutil"
            diskutil.write_text('#!/bin/zsh\nif [[ ! -e "$FINDER2RIGHT_TEST_FAILED" ]]; then\n'
                                '  touch "$FINDER2RIGHT_TEST_FAILED"\n  exit 1\nfi\n'
                                'exec /usr/sbin/diskutil "$@"\n')
            diskutil.chmod(0o755)
            environment["PATH"] = f"{shim}:{environment['PATH']}"
            environment["FINDER2RIGHT_TEST_FAILED"] = str(self.root / "failed-once")
        attach_call = next(line for line in entry.splitlines() if line.startswith('attach_image "$dmg_work/writable'))
        eject_call = next(line for line in entry.splitlines() if line.startswith("eject_image ||"))
        probe = self.root / "probe.zsh"
        probe.write_text('set -euo pipefail\ndmg_work="$1"\ndmg_lock="$2"\n'
                         'dmg_resources="$3"\ndmg_python="$4"\ndmg_device=""\n'
                         + cleanup + "trap 'cleanup $?' EXIT\n" + functions + attach_call + "\n"
                         + ("" if parser_failure else eject_call + "\n"))
        try:
            result = subprocess.run(["/bin/zsh", str(probe), str(work), str(lock), str(resources),
                                     "/usr/bin/false" if parser_failure else sys.executable],
                                    env=environment, capture_output=True, text=True, timeout=60)
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            devices = io.StringIO()
            with contextlib.redirect_stdout(devices):
                dmg.owned_devices(work)
            self.assertEqual(devices.getvalue(), "", result.stderr)
            self.assertFalse(work.exists(), result.stderr)
            self.assertFalse(lock.exists(), result.stderr)
        finally:
            # A regression must not leave this test's image mounted.
            devices = io.StringIO()
            with contextlib.redirect_stdout(devices):
                dmg.owned_devices(work)
            for device in devices.getvalue().splitlines():
                subprocess.run(["/usr/sbin/diskutil", "eject", device], check=True, capture_output=True)

    def test_attach_parser_failure_cleans_up_mount_and_lock(self):
        self.mount_failure_check(parser_failure=True)

    def test_eject_failure_retries_owned_mount_in_cleanup(self):
        self.mount_failure_check(parser_failure=False)


if __name__ == "__main__":
    unittest.main(verbosity=2)
