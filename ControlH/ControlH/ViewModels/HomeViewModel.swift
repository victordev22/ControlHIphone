import Foundation
import Observation

// MARK: - UI State

enum HorasUiState {
    case initial
    case loading
    case success([Horas])
    case error(String)

    var horas: [Horas] {
        if case .success(let list) = self { return list }
        return []
    }
    var isLoading: Bool { if case .loading = self { return true }; return false }
    var errorMessage: String? {
        if case .error(let msg) = self { return msg }
        return nil
    }
}

struct UserUsageSummary: Identifiable {
    let user: String
    let totalMillis: TimeInterval
    var id: String { user }
}

@MainActor
@Observable
final class HomeViewModel {
    var horasUiState: HorasUiState = .initial
    var currentUserHours: Horas?
    var weeklyUsageSummary: [String: TimeInterval] = [:]
    var monthlyTotalMillis: TimeInterval = 0

    private let controlService = ControlService.shared

    // MARK: - Fetch

    func fetchHoras(_ userId: String) {
        guard !horasUiState.isLoading else { return }
        horasUiState      = .loading
        currentUserHours  = nil
        weeklyUsageSummary = [:]
        monthlyTotalMillis = 0

        Task {
            do {
                let list = try await controlService.getHoras()
                processHoras(list, userId: userId)
                horasUiState = .success(list)
            } catch {
                let msg = (error as? APIError)?.errorDescription ?? error.localizedDescription
                horasUiState = .error(msg)
            }
        }
    }

    // MARK: - Processing

    private func processHoras(_ list: [Horas], userId: String) {
        let cal   = Calendar.current
        let now   = Date()
        let today = cal.startOfDay(for: now)

        // Prefer the active session (hora_apagado == nil); fall back to the last session today
        let todayRecords = list.filter { h in
            h.user == userId &&
            h.hora_encendido.map { cal.isDate($0, inSameDayAs: today) } == true
        }
        currentUserHours = todayRecords.first(where: { $0.isOn }) ?? todayRecords.last

        let weekComponents = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        var usageMap: [String: TimeInterval] = [:]
        let dayNames    = ["", "Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"]
        let todayWeekday = cal.component(.weekday, from: now)

        for h in list where h.user == userId {
            guard let start = h.hora_encendido else { continue }
            let hc = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: start)
            guard hc.yearForWeekOfYear == weekComponents.yearForWeekOfYear,
                  hc.weekOfYear == weekComponents.weekOfYear else { continue }
            let weekday = cal.component(.weekday, from: start)
            guard weekday >= 2, weekday <= 6, weekday <= todayWeekday else { continue }
            let end      = h.hora_apagado ?? now
            let duration = max(0, end.timeIntervalSince(start))
            let name     = dayNames[weekday]
            usageMap[name, default: 0] += duration
        }
        weeklyUsageSummary = usageMap

        let nowYear  = cal.component(.year,  from: now)
        let nowMonth = cal.component(.month, from: now)
        monthlyTotalMillis = list
            .filter { $0.user == userId }
            .reduce(0.0) { acc, h in
                guard let start = h.hora_encendido else { return acc }
                guard cal.component(.year,  from: start) == nowYear,
                      cal.component(.month, from: start) == nowMonth else { return acc }
                let end = h.hora_apagado ?? now
                return acc + max(0, end.timeIntervalSince(start))
            }
    }

    // MARK: - Admin helpers

    func adminWeeklyLeast(from horasData: [Horas]) -> [UserUsageSummary] {
        let cal  = Calendar.current
        let now  = Date()
        let weekComponents = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)

        return Dictionary(grouping: horasData.filter { $0.hora_encendido != nil }, by: { $0.user })
            .compactMap { (user, sessions) -> UserUsageSummary? in
                let total: TimeInterval = sessions.reduce(0) { acc, h in
                    guard let start = h.hora_encendido else { return acc }
                    let hc = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: start)
                    guard hc.yearForWeekOfYear == weekComponents.yearForWeekOfYear,
                          hc.weekOfYear == weekComponents.weekOfYear else { return acc }
                    return acc + max(0, (h.hora_apagado ?? now).timeIntervalSince(start))
                }
                return total > 0 ? UserUsageSummary(user: user, totalMillis: total) : nil
            }
            .sorted { $0.totalMillis < $1.totalMillis }
            .prefix(3)
            .map { $0 }
    }

    func adminMonthlyLeast(from horasData: [Horas]) -> [UserUsageSummary] {
        let cal      = Calendar.current
        let now      = Date()
        let nowYear  = cal.component(.year,  from: now)
        let nowMonth = cal.component(.month, from: now)

        return Dictionary(grouping: horasData.filter { $0.hora_encendido != nil }, by: { $0.user })
            .compactMap { (user, sessions) -> UserUsageSummary? in
                let total: TimeInterval = sessions.reduce(0) { acc, h in
                    guard let start = h.hora_encendido else { return acc }
                    guard cal.component(.year,  from: start) == nowYear,
                          cal.component(.month, from: start) == nowMonth else { return acc }
                    return acc + max(0, (h.hora_apagado ?? now).timeIntervalSince(start))
                }
                return total > 0 ? UserUsageSummary(user: user, totalMillis: total) : nil
            }
            .sorted { $0.totalMillis < $1.totalMillis }
            .prefix(3)
            .map { $0 }
    }
}
