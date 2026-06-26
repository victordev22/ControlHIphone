import Foundation
import BackgroundTasks
import UserNotifications

// Replaces Android NotificationWorker (WorkManager) with iOS BGTaskScheduler
final class NotificationManager {
    static let shared = NotificationManager()

    private let taskIdentifier = "com.controlh.daily_check"
    private let authService    = AuthService.shared
    private let controlService = ControlService.shared

    private init() {}

    // MARK: - Registration (call from AppDelegate / App init)

    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { [weak self] task in
            self?.handleAppRefresh(task: task as! BGProcessingTask)
        }
    }

    // MARK: - Schedule next execution

    func scheduleNextCheck(targetTime: String? = nil, retryIn15Min: Bool = false) {
        let request = BGProcessingTaskRequest(identifier: taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false

        if retryIn15Min {
            request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        } else {
            let seconds = secondsUntilTarget(timeString: targetTime ?? TokenManager.shared.getOfControl() ?? "18:00:00")
            request.earliestBeginDate = Date(timeIntervalSinceNow: max(60, seconds))
        }

        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: - Task handler

    private func handleAppRefresh(task: BGProcessingTask) {
        task.expirationHandler = {
            // System asked us to stop — reschedule
            self.scheduleNextCheck()
            task.setTaskCompleted(success: false)
        }

        Task {
            guard TokenManager.shared.getToken() != nil else {
                scheduleNextCheck()
                task.setTaskCompleted(success: true)
                return
            }

            var targetTime = TokenManager.shared.getOfControl() ?? "18:00:00"
            var myUser     = TokenManager.shared.getNickname() ?? ""
            var emailUser  = TokenManager.shared.getNovuEmail() ?? ""

            // Refresh user data
            if let userMe = try? await authService.getCurrentUser() {
                if let nick = userMe.nickname { myUser = nick; TokenManager.shared.saveNickname(nick) }
                if let mail = userMe.email    { emailUser = mail }

                
                // ✅ Después
                let ofControl: String?
                if let local = userMe.of_control, !local.isEmpty {
                    ofControl = local
                } else {
                    ofControl = try? await authService.getUserByEmail(emailUser).of_control
                }
                if let t = ofControl, !t.isEmpty {
                    targetTime = t
                    TokenManager.shared.saveOfControl(t)
                }
            }

            // Check if PC is still on after target time
            var isPcStillOn = false
            if !isBefore(now: Date(), targetString: targetTime) {
                if let list = try? await controlService.getHoras() {
                    isPcStillOn = list.contains {
                        $0.user.lowercased() == myUser.lowercased() && $0.isOn
                    }
                }
            }

            // Send local notification if PC is still on
            if isPcStillOn && !emailUser.isEmpty {
                await NovuService.shared.enviarNotificacion(email: emailUser)
                sendLocalNotification()
            }

            scheduleNextCheck(targetTime: targetTime, retryIn15Min: isPcStillOn)
            task.setTaskCompleted(success: true)
        }
    }

    // MARK: - Local push fallback

    private func sendLocalNotification() {
        let content = UNMutableNotificationContent()
        content.title = "ControlH"
        content.body  = "Tu equipo sigue encendido. Por favor, apágalo al terminar."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Request notification permission

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // MARK: - Helpers

    private func isBefore(now: Date, targetString: String) -> Bool {
        let cal  = Calendar.current
        let nowComponents = cal.dateComponents([.hour, .minute, .second], from: now)
        let parts = targetString.split(separator: ":").map { Int($0) ?? 0 }
        guard parts.count >= 2 else { return true }
        let nowSec    = (nowComponents.hour ?? 0) * 3600 + (nowComponents.minute ?? 0) * 60 + (nowComponents.second ?? 0)
        let targetSec = parts[0] * 3600 + parts[1] * 60 + (parts.count > 2 ? parts[2] : 0)
        return nowSec < targetSec
    }

    private func secondsUntilTarget(timeString: String) -> TimeInterval {
        let cal  = Calendar.current
        let now  = Date()
        let nowComponents = cal.dateComponents([.hour, .minute, .second], from: now)
        let parts = timeString.split(separator: ":").map { Int($0) ?? 0 }
        guard parts.count >= 2 else { return 3600 }

        let nowSec    = (nowComponents.hour ?? 0) * 3600 + (nowComponents.minute ?? 0) * 60 + (nowComponents.second ?? 0)
        let targetSec = parts[0] * 3600 + parts[1] * 60 + (parts.count > 2 ? parts[2] : 0)
        var diff = TimeInterval(targetSec - nowSec)
        if diff <= 0 { diff += 24 * 3600 }
        return diff
    }
}
