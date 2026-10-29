import Foundation

/// Una opción del menú: su texto, el comando que lanza y si está activa.
public struct MenuAction: Equatable, Sendable, Identifiable {
  public let title: String
  public let command: GuardianCommand
  public var enabled: Bool

  public var id: String { title }

  public init(_ title: String, _ command: GuardianCommand, enabled: Bool = true) {
    self.title = title
    self.command = command
    self.enabled = enabled
  }
}

/// Las opciones del menú para un estado (ver docs/fases/fase-5-app-barra-de-menus.md).
/// Las que no están disponibles aparecen desactivadas y su texto dice por qué.
/// Con `busy` (un comando en marcha) todas aparecen desactivadas.
public struct MenuModel: Equatable, Sendable {
  /// El pase; nil si no hay pases (PASS_MAX_PER_SESSION=0).
  public var pass: MenuAction?
  /// "Nueva sesión" o "Pasar a sesión por tiempo"; nil si no hay submenú.
  public var newSessionTitle: String?
  public var newSession: [MenuAction] = []
  /// "Terminar sesión"; nil sin sesión o durante una terminación pendiente.
  public var stop: MenuAction?
  /// "Seguir trabajando"; solo durante una terminación pendiente.
  public var cancelStop: MenuAction?

  public init(status: GuardianStatus, now: Int, busy: Bool = false, timeZone: TimeZone = .current) {
    pass = Self.pass(status, now: now, timeZone: timeZone)
    switch status.session {
    case .none:
      newSessionTitle = "Nueva sesión"
      newSession = status.timedPresets.map { MenuAction("\($0) min", .startTimed($0)) } + [MenuAction("Sin fin", .start)]
    case .indefinite:
      // S2 de la Fase 4: la sesión sin fin pasa a terminar dentro de N minutos,
      // pero nunca antes que el retraso al terminar (el motor la alarga).
      newSessionTitle = "Pasar a sesión por tiempo"
      newSession = status.timedPresets.map { Self.convert($0, delay: status.stopDelayMinutes) }
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

  static func pass(_ status: GuardianStatus, now: Int, timeZone: TimeZone) -> MenuAction? {
    guard status.passesMax > 0 else { return nil }
    let name = "Pase " + GroupNames.list(status.passGroups)
    if status.session == .none {
      return MenuAction("\(name): solo durante una sesión", .pass, enabled: false)
    }
    if status.passActive(at: now) {
      let until = TimeText.clock(status.passUntil, timeZone: timeZone)
      return MenuAction("\(name): en curso hasta las \(until)", .pass, enabled: false)
    }
    if status.passesLeft == 0 {
      return MenuAction("\(name): no quedan (\(status.passesUsed) de \(status.passesMax))", .pass, enabled: false)
    }
    return MenuAction("\(name), \(status.passMinutes) min (quedan \(status.passesLeft))", .pass)
  }

  /// El comando lleva siempre la duración de TIMED_PRESETS (la regla de sudoers
  /// solo admite esas); el texto avisa si el motor la va a alargar.
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
    pass?.enabled = false
    stop?.enabled = false
    cancelStop?.enabled = false
    for index in newSession.indices { newSession[index].enabled = false }
  }
}
