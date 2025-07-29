import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    private let scheduler = MedicationScheduler()
    private let userSettings = UserSettings.shared // <-- Access the user settings

    func removeAllPendingReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("All pending medication reminders have been removed.")
    }

    func scheduleMedicationReminders(for medications: [Medication]) {
        removeAllPendingReminders()
        let center = UNUserNotificationCenter.current()
        
        for medication in medications {
            let times = generateSuggestedTimes(frequency: Int(medication.frequency) ?? 1, timing: medication.timing)
            
            for (time, label) in times {
                let content = UNMutableNotificationContent()
                content.title = "Medication Reminder"
                content.body = "It's time to take your \(medication.name)."
                content.sound = .default

                let triggerDate = Calendar.current.dateComponents([.hour, .minute], from: time)
                let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: true)
                let requestIdentifier = "\(medication.id ?? UUID().uuidString)-\(label)"
                let request = UNNotificationRequest(identifier: requestIdentifier, content: content, trigger: trigger)
                
                center.add(request) { error in
                    if let error = error {
                        print("Error scheduling notification for \(medication.name): \(error.localizedDescription)")
                    } else {
                        print("Successfully scheduled reminder for \(medication.name) at \(label)")
                    }
                }
            }
        }
    }

    private func generateSuggestedTimes(frequency: Int, timing: String?) -> [(Date, String)] {
        var times: [(Date, String)] = []
        let timingLowercased = timing?.lowercased() ?? ""

        if timingLowercased.contains("bedtime") {
            return [(userSettings.bedtimeTime, "Bedtime")]
        }
        if timingLowercased.contains("morning") {
            return [(userSettings.morningTime, "Morning")]
        }
        if timingLowercased.contains("afternoon") {
            return [(userSettings.afternoonTime, "Afternoon")]
        }
        if timingLowercased.contains("evening") {
            return [(userSettings.eveningTime, "Evening")]
        }

        switch frequency {
        case 1:
            times.append((userSettings.morningTime, "Morning"))
        case 2:
            times.append((userSettings.morningTime, "Morning"))
            times.append((userSettings.eveningTime, "Evening"))
        case 3:
            times.append((userSettings.morningTime, "Morning"))
            times.append((userSettings.afternoonTime, "Afternoon"))
            times.append((userSettings.eveningTime, "Evening"))
        case 4:
            times.append((userSettings.morningTime, "Morning"))
            times.append( (Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!, "Noon"))
            times.append((userSettings.eveningTime, "Evening"))
            times.append((userSettings.bedtimeTime, "Bedtime"))
        default:
            if frequency > 0 { // Distribute evenly for higher frequencies
                let interval = 24 / frequency
                for i in 0..<frequency {
                    if let date = Calendar.current.date(byAdding: .hour, value: i * interval, to: userSettings.morningTime) {
                        times.append((date, date.formatted(date: .omitted, time: .shortened)))
                    }
                }
            }
        }
        return times
    }
}
