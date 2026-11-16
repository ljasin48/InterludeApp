import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

extension Notification.Name {
    static let interludeAdd = Notification.Name("com.loganjasin.Interlude.add")
}

@MainActor
final class InterludeQuickAction {
    static let shared = InterludeQuickAction()
    static let addType = "com.loganjasin.Interlude.add"

    private var wantsAdd = false

    static func matches(_ url: URL) -> Bool {
        url.scheme == "interlude" && url.host == "add"
    }

    #if os(iOS)
    func requestAdd(_ item: UIApplicationShortcutItem) {
        guard item.type == Self.addType else { return }
        markAdd()
    }
    #endif

    func requestAddFromMenu() {
        markAdd()
    }

    func consumeAdd() -> Bool {
        let pending = wantsAdd
        wantsAdd = false
        return pending
    }

    private func markAdd() {
        wantsAdd = true
        NotificationCenter.default.post(name: .interludeAdd, object: nil)
    }
}

#if os(iOS)
final class InterludeAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        if connectingSceneSession.role == .windowApplication {
            configuration.delegateClass = InterludeSceneDelegate.self
        }
        return configuration
    }
}

final class InterludeSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        if let shortcutItem = connectionOptions.shortcutItem {
            Task { @MainActor in
                InterludeQuickAction.shared.requestAdd(shortcutItem)
            }
        }
    }

    // UIKit invokes this requirement off the main actor. UIApplicationShortcutItem
    // is not Sendable, so copy its type before hopping to the main actor.
    nonisolated func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem
    ) async -> Bool {
        let type = shortcutItem.type
        return await MainActor.run {
            guard type == InterludeQuickAction.addType else { return false }
            InterludeQuickAction.shared.requestAddFromMenu()
            return true
        }
    }
}
#endif

#if os(macOS)
final class InterludeMacDelegate: NSObject, NSApplicationDelegate {
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        let item = NSMenuItem(title: "Add new interlude", action: #selector(addInterlude(_:)), keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return menu
    }

    @objc private func addInterlude(_ sender: Any?) {
        Task { @MainActor in
            InterludeQuickAction.shared.requestAddFromMenu()
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}
#endif
