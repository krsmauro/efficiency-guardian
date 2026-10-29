import Foundation
import GuardianCore
import UserNotifications

/// Envía las notificaciones del sistema. Qué avisar lo decide NotificationPlanner;
/// el arranque ya avisado se guarda para no repetirlo si la app se vuelve a abrir.
///
/// Solo funciona dentro del paquete .app (necesita un identificador): con el
/// binario suelto (swift run) no hace nada.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
  static let announcedBootKey = "announcedBoot"

  private var planner = NotificationPlanner(
    announcedBoot: UserDefaults.standard.integer(forKey: announcedBootKey))
  private let center: UNUserNotificationCenter? =
    Bundle.main.bundleIdentifier == nil ? nil : UNUserNotificationCenter.current()

  override init() {
    super.init()
    center?.delegate = self
  }

  /// La primera vez, macOS pregunta al usuario. Si dice que no, los avisos no
  /// llegan, pero la app funciona igual.
  func requestPermission() {
    center?.requestAuthorization(options: [.alert]) { _, _ in }
  }

  /// Avisa de lo que acaba de pasar con este estado y esta hora.
  func update(_ status: GuardianStatus, now: Int) {
    post(planner.notifications(for: status, now: now, bootTime: SystemClock.bootTime))
    if UserDefaults.standard.integer(forKey: Self.announcedBootKey) != planner.announcedBoot {
      UserDefaults.standard.set(planner.announcedBoot, forKey: Self.announcedBootKey)
    }
  }

  private func post(_ notifications: [AppNotification]) {
    guard let center else { return }
    for notification in notifications {
      let content = UNMutableNotificationContent()
      content.title = notification.title
      content.body = notification.body
      center.add(UNNotificationRequest(identifier: notification.id, content: content, trigger: nil))
    }
  }

  /// Mostrar el aviso también si la app está activa (por ejemplo, con el menú abierto).
  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    [.banner, .list]
  }
}
