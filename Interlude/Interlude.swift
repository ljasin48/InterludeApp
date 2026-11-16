import SwiftUI

@main struct Interlude: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(InterludeAppDelegate.self) private var appDelegate
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor(InterludeMacDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
