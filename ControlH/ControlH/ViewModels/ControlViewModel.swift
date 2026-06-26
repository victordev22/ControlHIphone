import Foundation
import Observation

struct PowerUiState {
    var isPoweredOn:  Bool  = false
    var isConnecting: Bool  = false
    var errorMessage: String?
}

@MainActor
@Observable
final class ControlViewModel {
    var uiState = PowerUiState()

    private var lastUserId    = ""
    private var lastUserEmail = ""
    private let controlService = ControlService.shared
    private let authService    = AuthService.shared

    // MARK: - Toggle PC power

    func togglePower() {
        let suffix  = lastUserId.suffix(2).uppercased()
        let command = uiState.isPoweredOn ? "sh \(suffix)_off.sh" : "sh \(suffix).sh"

        uiState.isConnecting = true
        uiState.errorMessage = nil

        Task {
            defer { uiState.isConnecting = false }
            do {
                try await authService.sendCommand(command)
                uiState.isPoweredOn.toggle()
                if !lastUserId.isEmpty {
                    await refreshPowerState(userId: lastUserId, userEmail: lastUserEmail)
                }
            } catch {
                uiState.errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    // MARK: - Sync from HomeViewModel result

    func syncPowerState(_ isOn: Bool) {
        uiState.isPoweredOn  = isOn
        uiState.isConnecting = false
    }

    // MARK: - Refresh from /control/listhoras

    func refreshPowerState(userId: String, userEmail: String = "") async {
        guard !userId.isEmpty else { return }
        lastUserId    = userId
        lastUserEmail = userEmail
        uiState.isConnecting = true
        uiState.errorMessage = nil

        do {
            let list = try await controlService.getHoras()
            let isOn = list.contains { h in
                guard h.hora_apagado == nil else { return false }
                return h.user.lowercased() == userId.lowercased()
                    || (!userEmail.isEmpty && h.user.lowercased() == userEmail.lowercased())
            }
            uiState.isPoweredOn  = isOn
            uiState.isConnecting = false
        } catch {
            uiState.isConnecting = false
            uiState.errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}
