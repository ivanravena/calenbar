import Foundation
import ServiceManagement

@MainActor
enum LaunchAtLoginController {
    private static var service: SMAppService { SMAppService.mainApp }

    static var requiresApproval: Bool {
        service.status == .requiresApproval
    }

    static var isEffectivelyEnabled: Bool {
        switch service.status {
        case .enabled, .requiresApproval:
            return true
        case .notRegistered, .notFound:
            return false
        @unknown default:
            return false
        }
    }

    static func apply(enabled: Bool) throws {
        if enabled {
            try service.register()
        } else {
            try service.unregister()
        }
    }

    static func syncPreferenceToSystem(_ enabled: Bool) {
        do {
            try apply(enabled: enabled)
        } catch {
            // User may have denied the login item in System Settings.
        }
    }

    static func refreshFromSystem(into settings: AppSettings) {
        settings.updateLaunchAtLoginState(
            effectiveEnabled: isEffectivelyEnabled,
            requiresApproval: requiresApproval
        )
    }
}
