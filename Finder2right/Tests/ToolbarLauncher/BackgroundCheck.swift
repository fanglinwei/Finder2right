import AppKit

let mainURL = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
let launcherURL = mainURL.appendingPathComponent("Contents/Helpers/Finder2right Launcher.app")
let workspace = NSWorkspace.shared
let originalPID = workspace.frontmostApplication?.processIdentifier
precondition(originalPID != nil)
precondition(!workspace.runningApplications.contains { $0.bundleURL?.standardizedFileURL == mainURL },
             "Quit the test App before checking a cold toolbar launch")
let configuration = NSWorkspace.OpenConfiguration()
configuration.activates = false
configuration.addsToRecentItems = false
var completed = false
var launchError: Error?
workspace.openApplication(at: launcherURL, configuration: configuration) { _, error in
    DispatchQueue.main.async {
        launchError = error
        completed = true
    }
}
let deadline = Date().addingTimeInterval(5)
var samples = 0
var focusChanged = false
var wrongPolicy = false
while Date() < deadline {
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    if let app = workspace.runningApplications.first(where: { $0.bundleURL?.standardizedFileURL == mainURL }) {
        samples += 1
        wrongPolicy = wrongPolicy || app.activationPolicy != .accessory
    }
    focusChanged = focusChanged || workspace.frontmostApplication?.processIdentifier != originalPID
}
let remaining = workspace.runningApplications.first { $0.bundleURL?.standardizedFileURL == mainURL }
print("Launch completed:", completed, "error:", String(describing: launchError))
print("Main App samples:", samples, "still running:", remaining != nil)
print("Unexpected Dock activation policy:", wrongPolicy, "foreground changed:", focusChanged)
remaining?.terminate()
assert(completed && launchError == nil)
assert(samples > 20 && remaining != nil, "Background menu did not remain available")
assert(!wrongPolicy, "Toolbar launch must stay out of the Dock")
assert(!focusChanged, "Toolbar launch must preserve foreground application")
print("PASS: cold toolbar launch stays accessory and preserves foreground application")
