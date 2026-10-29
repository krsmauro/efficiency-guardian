import Foundation

/// Las opciones del menú para un estado (ver docs/fases/fase-5-app-barra-de-menus.md
/// y, para alargar, acortar y los pases por sitio, la Fase 6).
/// Las que no están disponibles aparecen desactivadas y su texto dice por qué.
/// Con `busy` (un comando en marcha) todas aparecen desactivadas.
public struct MenuModel: Equatable, Sendable {
  /// El pase (ver PassMenu); nil si no hay pases (PASS_MAX_PER_SESSION=0).
  public var pass: MenuEntry?
  /// "Nueva sesión ▸" o "Pasar a sesión por tiempo ▸"; nil con una sesión por tiempo.
  public var newSession: Submenu?
  /// "Alargar ▸" y "Acortar ▸" (ver SessionLengthMenu): solo con una sesión por
  /// tiempo y sin terminación pendiente (primero "Seguir trabajando").
  public var extend: Submenu?
  public var shorten: Submenu?
  /// "Terminar sesión"; nil sin sesión o durante una terminación pendiente.
  public var stop: MenuAction?
  /// "Seguir trabajando"; solo durante una terminación pendiente.
  public var cancelStop: MenuAction?

  public init(status: GuardianStatus, now: Int, busy: Bool = false, timeZone: TimeZone = .current) {
    pass = PassMenu.entry(status, now: now, timeZone: timeZone)
    switch status.session {
    case .none:
      newSession = Submenu("Nueva sesión",
                           status.timedPresets.map { MenuAction("\($0) min", .startTimed($0)) } + [MenuAction("Sin fin", .start)])
    case .indefinite:
      // S2 de la Fase 4: la sesión sin fin pasa a terminar dentro de N minutos,
      // pero nunca antes que el retraso al terminar (el motor la alarga).
      newSession = Submenu("Pasar a sesión por tiempo",
                           status.timedPresets.map { Self.convert($0, delay: status.stopDelayMinutes) })
    case .timed where !status.stopPending:
      extend = SessionLengthMenu.extend(status, timeZone: timeZone)
      shorten = SessionLengthMenu.shorten(status, now: now, timeZone: timeZone)
    case .timed:
      break
    }
    if status.stopPending {
      cancelStop = MenuAction("Seguir trabajando", .cancelStop)
    } else if status.session != .none {
      stop = Self.stop(status, now: now, timeZone: timeZone)
    }
    if busy { disableAll() }
  }

  /// El comando lleva siempre la duración de TIMED_PRESETS (el motor solo
  /// admite esas); el texto avisa si el motor la va a alargar.
  static func convert(_ minutes: Int, delay: Int) -> MenuAction {
    let title = minutes < delay ? "\(minutes) min (serán \(delay): el retraso al terminar)" : "\(minutes) min"
    return MenuAction(title, .startTimed(minutes))
  }

  static func stop(_ status: GuardianStatus, now: Int, timeZone: TimeZone) -> MenuAction {
    let ends = TimeText.clock(status.sessionEnds, timeZone: timeZone)
    if status.session == .timed && status.timedLock {
      return MenuAction("Terminar: con candado hasta las \(ends)", .stop, enabled: false)
    }
    if status.session == .timed && status.sessionEnds - now <= status.stopDelayMinutes * 60 {
      return MenuAction("Terminar sesión (ya termina a las \(ends))", .stop)
    }
    if status.stopDelayMinutes > 0 {
      return MenuAction("Terminar sesión (en \(status.stopDelayMinutes) min)", .stop)
    }
    return MenuAction("Terminar sesión", .stop)
  }

  mutating func disableAll() {
    pass?.disable()
    newSession?.disableItems()
    extend?.disableItems()
    shorten?.disableItems()
    stop?.enabled = false
    cancelStop?.enabled = false
  }
}
