import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginController {
    enum LaunchStatus: Equatable {
        case enabled
        case disabled
        case needsApproval
        case unavailable

        var isEnabled: Bool {
            self == .enabled
        }

        var description: String {
            switch self {
            case .enabled:
                return "Launch at login: on"
            case .disabled:
                return "Launch at login: off"
            case .needsApproval:
                return "Launch at login: needs approval in System Settings"
            case .unavailable:
                return "Launch at login: unavailable"
            }
        }
    }

    var status: LaunchStatus {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .needsApproval
        case .notRegistered:
            return .disabled
        case .notFound:
            return .unavailable
        @unknown default:
            return .unavailable
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
