# Finder2right DMG 打包

参考 Combo 的 Releases 结构，生成仅支持 Apple Silicon 的拖动安装镜像。默认命令：

```sh
./Releases/package-dmg.sh
```

脚本根据自身位置定位项目，也可进入 Releases 后执行。它构建当前源码的 Release（纯 arm64），输出：

- `Releases/Finder2right-<版本号>-arm64.dmg`
- `Releases/安装指南.html`

版本号、独立 build 号和最低 macOS 版本取自实际 App 的 Info.plist，且必须与内置 Finder 扩展一致。当前为 0.1.0、Build 1、macOS 14.0。不会修改项目版本或 Debug 构建的架构设置。

已有纯 arm64 的 Release App 时，可跳过构建：

```sh
./Releases/package-dmg.sh --app "/absolute/path/to/Finder2right.app"
```

传入的 App 必须包含可执行的 FinderExtension，主 App 与所有嵌套 Mach-O 都必须是纯 arm64。脚本只在临时副本上清理扩展属性并重新签名，不修改传入的 App。

## 环境

- macOS、完整 Xcode；默认源码构建需要 Apple Silicon Mac。
- Python 3.10 或更高版本，支持 venv 和 pip。首次运行创建 `build/dmg-venv` 并安装 `requirements.txt` 中固定版本的 ds_store 和 mac_alias；之后可离线打包。
- Xcode 默认路径为 `/Applications/Xcode.app/Contents/Developer`，可用 `FINDER2RIGHT_DEVELOPER_DIR` 覆盖。

```sh
FINDER2RIGHT_DEVELOPER_DIR="/path/to/Xcode.app/Contents/Developer" ./Releases/package-dmg.sh
```

## 镜像内容

DMG 使用 HFS+、UDZO 压缩，Finder 窗口为 760 × 528，背景为 760 × 500 逻辑点、1520 × 1000 像素。上排是 Finder2right → Applications 拖动安装入口，下排是安装指南与清除下载隔离脚本。两个辅助入口使用自定义文档、终端图标并隐藏扩展名。

指南由 HTML 模板生成，可离线阅读，包含安装、启用 Finder 扩展、Finder 工具栏、Terminal 自动化权限及首次启动说明。模板保留 `@VERSION@`、`@BUILD@`、`@MINIMUM_MACOS@`、`@DMG_NAME@` 四个占位符。

安装辅助脚本只处理固定的 `/Applications/Finder2right.app`，核对 App 标识后等待用户确认，仅递归删除 `com.apple.quarantine` 属性，保留其他扩展属性，不跟随符号链接。它不修改系统全局来源限制；打包及测试不会运行此安装脚本，也不会处理本机已安装的 App。回归测试只在独立临时目录中验证同一条属性删除命令。

本流程使用 ad-hoc 签名，没有 Developer ID 分发签名或 Apple 公证。Finder 扩展保留现有 sandbox 和配置目录只读临时例外；没有迁移 App Groups。跨机器的扩展注册、Gatekeeper 放行与 Terminal 授权需要实际安装验证。本项目尚未接入 Sparkle，因此不复制 Combo 的 updates 工具，也不生成更新源或执行线上发布。

## 校验与失败恢复

打包校验 App 和 Finder 扩展的标识、版本、执行权限、所有 Mach-O 架构、嵌套签名和扩展 entitlements。写入 Finder 布局后，再校验镜像文件哈希、自定义图标、Applications 链接和脚本权限；压缩后重新挂载只读镜像复查，并执行 `hdiutil verify`。

同版本重跑会替换同名 DMG。只有校验通过后，才将新 DMG 与指南放入 Releases；第二份文件替换失败或收到正常终止信号时，会回滚两份文件并保留旧数据和图标资源。`publish` 是本地文件替换步骤，不上传文件，不创建 GitHub Release，不执行 Git 操作。

运行期间以 `build/dmg-package.lock` 防止并发，只自动卸载本次创建的临时镜像；输出 DMG 已挂载时会停止。若无法确认临时镜像已卸载，保留工作目录并报告位置。断电或 kill -9 无法触发清理；若遗留锁或 `.finder2right-publish-*` 备份，请先确认没有打包任务、弹出相关镜像并恢复备份，再处理空锁目录。

构建日志为 `build/dmg-release-build.log`；镜像完整性日志为 `build/dmg-package-verify.log`。DMG 和 Python 缓存不加入 Git，源码工具、资源和生成指南可供检查。

## 回归检查与资源重绘

首次打包安装布局依赖后：

```sh
./build/dmg-venv/bin/python Releases/packaging/test-dmg.py
```

测试覆盖执行权限、Finder 扩展缺失及版本不一致、拒绝 universal 架构、隔离属性处理范围、输出锁定、发布失败回滚、信号中断，以及真实临时镜像的设备解析和卸载失败恢复。测试不替换正式 DMG。

两枚辅助图标及背景均有可编辑的 Swift 来源；资源不在每次打包时重绘：

```sh
xcrun swift Releases/packaging/render-icons.swift Releases/packaging/assets
xcrun swift Releases/packaging/render-background.swift Releases/packaging/assets/background.tiff
```

`set-icons.swift` 每次打包为辅助文件设置图标与隐藏扩展名；`dmg.py` 生成 `.DS_Store` 并校验镜像。清理 build 后可重新打包。
