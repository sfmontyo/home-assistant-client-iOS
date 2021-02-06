import Foundation
import AppKit
import ServiceManagement

@objc(HAMacBridgeImpl) final class MacBridgeImpl: NSObject, MacBridge {
    let networkMonitor: MacBridgeNetworkMonitor
    let statusItem: MacBridgeStatusItem?

    override init() {
        if Bundle.main.isRunningInExtension {
            // status item can't talk to the status bar in an extension or it will crash
            self.statusItem = nil
        } else {
            self.statusItem = MacBridgeStatusItem()
        }

        self.networkMonitor = MacBridgeNetworkMonitor()

        super.init()

        MacBridgeAppDelegateHandler.swizzleAppDelegate()
    }

    var terminationWillBeginNotification: Notification.Name {
        MacBridgeAppDelegateHandler.terminationWillBeginNotification
    }

    var distributedNotificationCenter: NotificationCenter {
        DistributedNotificationCenter.default()
    }

    var workspaceNotificationCenter: NotificationCenter {
        NSWorkspace.shared.notificationCenter
    }

    var networkConnectivity: MacBridgeNetworkConnectivity {
        networkMonitor.networkConnectivity
    }

    var networkConnectivityDidChangeNotification: Notification.Name {
        MacBridgeNetworkMonitor.connectivityDidChangeNotification
    }

    var screens: [MacBridgeScreen] {
        NSScreen.screens.map(MacBridgeScreenImpl.init(screen:))
    }

    var screensWillChangeNotification: Notification.Name {
        NSApplication.didChangeScreenParametersNotification
    }

    var frontmostApplication: MacBridgeRunningApplication? {
        NSWorkspace.shared.frontmostApplication
    }

    var frontmostApplicationDidChangeNotification: Notification.Name {
        NSWorkspace.didActivateApplicationNotification
    }

    var activationPolicy: MacBridgeActivationPolicy {
        get {
            switch NSApplication.shared.activationPolicy() {
            case .regular: return .regular
            case .accessory: return .accessory
            case .prohibited: return .prohibited
            @unknown default: return .regular
            }
        }
        set {
            if newValue != activationPolicy {
                NSApplication.shared.setActivationPolicy({
                    switch newValue {
                    case .regular: return .regular
                    case .accessory: return .accessory
                    case .prohibited: return .prohibited
                    }
                }())
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
        }
    }

    func configureStatusItem(using configuration: MacBridgeStatusItemConfiguration) {
        statusItem?.configure(using: configuration)
    }

    private static func userDefaultsKey(forLoginItemBundleIdentifier identifier: String) -> String {
        return "LoginItemEnabled-\(identifier)"
    }

    func setLoginItem(forBundleIdentifier identifier: String, enabled: Bool) -> Bool {
        let success = SMLoginItemSetEnabled(identifier as CFString, enabled)
        if success {
            UserDefaults.standard.set(enabled, forKey: Self.userDefaultsKey(forLoginItemBundleIdentifier: identifier))
        }
        return success
    }

    func isLoginItemEnabled(forBundleIdentifier identifier: String) -> Bool {
        // TODO: SMJobIsEnabled is the Apple-suggested method of getting this info, and it's also private API. lol.
        UserDefaults.standard.bool(forKey: Self.userDefaultsKey(forLoginItemBundleIdentifier: identifier))
    }
}

extension NSRunningApplication: MacBridgeRunningApplication {}
