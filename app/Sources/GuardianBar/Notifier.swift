import Foundation
import GuardianCore
import UserNotifications

/// Envía las notificaciones del sistema. Qué avisar lo decide NotificationPlanner.
///
/// Solo funciona dentro del paquete .app (necesita un identificador): con el
/// binario suelto (swift run) no hace nada.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
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

  func post(_ notifications: [AppNotification]) {
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
