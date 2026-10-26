import SwiftUI

@main
struct Finder2rightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings {
            MainView(store: delegate.store)
        }
    }
}
