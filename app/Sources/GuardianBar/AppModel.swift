import Foundation
import GuardianCore
import Observation

/// El estado que ve la interfaz: lee el estado del motor y ejecuta los comandos.
/// Qué se muestra lo decide GuardianCore; cuándo se vuelve a leer, Scheduler.
///
/// La interfaz solo observa `icon`, `screen` y la casilla de `loginItem`, y solo
/// se asignan cuando cambian: cada vez que SwiftUI redibuja el menú, macOS
/// cierra el submenú abierto (fallo de la verificación 5.6). El resto no se
/// observa: `now` cambia cada segundo y `result` en cada lectura.
@MainActor @Observable
final class AppModel {
  private(set) var icon = IconState.loading
  private(set) var screen = MenuSnapshot(result: .loading, now: 0, busy: false)

  @ObservationIgnored private(set) var result: StatusResult = .loading
  @ObservationIgnored private(set) var now = SystemClock.now
  /// Un comando en marcha: el menú desactiva las acciones.
  @ObservationIgnored private var busy = false
  @ObservationIgnored private(set) var reading = false
  @ObservationIgnored private var readAgain = false
  /// Reloj monótono: si alguien cambia la hora del Mac, el sondeo no se detiene.
  @ObservationIgnored private var lastRead: ContinuousClock.Instant?
  @ObservationIgnored private let notifier = Notifier()
  @ObservationIgnored private var scheduler: Scheduler?
  @ObservationIgnored let loginItem = LoginItemToggle()

  init() {
    notifier.requestPermission()
    LoginItem.registerOnFirstLaunch()
    loginItem.reread()
    scheduler = Scheduler(model: self)
    Task { await refresh() }
  }

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
      update()
    } while readAgain
    reading = false
    // La casilla también puede cambiar desde Ajustes del Sistema.
    loginItem.reread()
  }

  /// Cada segundo (lo llama Scheduler): avanza la cuenta atrás.
  func tick() {
    now = SystemClock.now
    update()
  }

  func run(_ command: GuardianCommand) async {
    guard !busy else { return }
    busy = true
    publish()
    let outcome = await GuardianClient.run(command)
    busy = false
    await refresh()
    if case .failure(let message) = outcome {
      Alerts.show("No se pudo hacer", message)
    }
  }

  private func update() {
    publish()
    if let status = result.status { notifier.update(status, now: now) }
  }

  /// Lo que ve la interfaz, asignado solo si cambió (ver arriba).
  private func publish() {
    let newIcon = IconState.from(result, now: now)
    if newIcon != icon { icon = newIcon }
    let newScreen = MenuSnapshot(result: result, now: now, busy: busy)
    if newScreen != screen { screen = newScreen }
  }
}
