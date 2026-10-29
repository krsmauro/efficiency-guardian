import Foundation
import GuardianCore
import Observation

/// El estado que ve la interfaz: lee el estado del motor y ejecuta los comandos.
/// Qué se muestra lo decide GuardianCore; cuándo se vuelve a leer, Scheduler.
@MainActor @Observable
final class AppModel {
  static let announcedBootKey = "announcedBoot"

  private(set) var result: StatusResult = .loading
  private(set) var now = SystemClock.now
  /// Un comando en marcha: el menú desactiva las acciones.
  private(set) var busy = false
  private(set) var opensAtLogin = LoginItem.isEnabled

  @ObservationIgnored private(set) var reading = false
  @ObservationIgnored private var readAgain = false
  /// Reloj monótono: si alguien cambia la hora del Mac, el sondeo no se detiene.
  @ObservationIgnored private var lastRead: ContinuousClock.Instant?
  @ObservationIgnored private var planner = NotificationPlanner(
    announcedBoot: UserDefaults.standard.integer(forKey: announcedBootKey))
  @ObservationIgnored private let notifier = Notifier()
  @ObservationIgnored private var scheduler: Scheduler?

  init() {
    notifier.requestPermission()
    LoginItem.registerOnFirstLaunch()
    opensAtLogin = LoginItem.isEnabled
    scheduler = Scheduler(model: self)
    Task { await refresh() }
  }

  var icon: IconState { IconState.from(result, now: now) }
  var summary: [String] { MenuSummary.lines(result, now: now) }
  var menu: MenuModel? { result.status.map { MenuModel(status: $0, now: now, busy: busy) } }

  /// Segundos desde la última lectura (o muchísimos si aún no hubo ninguna).
  var secondsSinceRead: Int {
    lastRead.map { Int((ContinuousClock.now - $0).components.seconds) } ?? .max
  }

  /// Vuelve a leer el estado. Si ya hay una lectura en marcha, se repite al
  /// terminar (así no se pierde un cambio que llegó mientras tanto).
  func refresh() async {
    if reading {
      readAgain = true
      return
    }
    reading = true
    repeat {
      readAgain = false
      let latest = await GuardianClient.status()
      now = SystemClock.now
      lastRead = ContinuousClock.now
      result = latest
      notify()
    } while readAgain
    reading = false
    // La casilla también puede cambiar desde Ajustes del Sistema.
    opensAtLogin = LoginItem.isEnabled
  }

  /// Cada segundo (lo llama Scheduler): avanza la cuenta atrás.
  func tick() {
    now = SystemClock.now
    notify()
  }

  func run(_ command: GuardianCommand) async {
    guard !busy else { return }
    busy = true
    let outcome = await GuardianClient.run(command)
    busy = false
    await refresh()
    if case .failure(let message) = outcome {
      Alerts.show("No se pudo hacer", message)
    }
  }

  func setOpensAtLogin(_ enabled: Bool) {
    if let error = LoginItem.set(enabled) {
      Alerts.show("No se pudo cambiar el inicio de sesión", error)
    }
    opensAtLogin = LoginItem.isEnabled
  }

  private func notify() {
    guard let status = result.status else { return }
    notifier.post(planner.notifications(for: status, now: now, bootTime: SystemClock.bootTime))
    // Se guarda para no repetir el aviso del arranque si la app se vuelve a abrir.
    if UserDefaults.standard.integer(forKey: Self.announcedBootKey) != planner.announcedBoot {
      UserDefaults.standard.set(planner.announcedBoot, forKey: Self.announcedBootKey)
    }
  }
}
