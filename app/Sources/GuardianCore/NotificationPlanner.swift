/// Una notificación para el usuario. Una nueva con el mismo `id` reemplaza a la anterior.
public struct AppNotification: Equatable, Sendable {
  public let id: String
  public let title: String
  public let body: String
}

/// Decide qué notificaciones enviar (ver la tabla en la especificación de la Fase 5).
///
/// La app lo llama con cada estado leído y con cada segundo que pasa; recuerda
/// el estado anterior para ver qué cambió. Solo avisa de lo que acaba de pasar
/// (`recent`): tras un reposo largo no llegan avisos viejos.
public struct NotificationPlanner: Sendable {
  static let recent = 120
  static let autostartWindow = 600

  private var previous: GuardianStatus?
  private var warnedPassUntil = 0
  /// El arranque cuyo aviso ya se dio. La app lo guarda entre aperturas.
  public private(set) var announcedBoot: Int

  public init(announcedBoot: Int = 0) {
    self.announcedBoot = announcedBoot
  }

  /// `bootTime`: cuándo arrancó el Mac (kern.boottime), en epoch.
  public mutating func notifications(for status: GuardianStatus, now: Int, bootTime: Int) -> [AppNotification] {
    var result: [AppNotification] = []
    if let previous { result += changes(from: previous, to: status, now: now) }
    if let warning = passWarning(status, now: now) { result.append(warning) }
    if let autostart = autostart(status, now: now, bootTime: bootTime) { result.append(autostart) }
    previous = status
    return result
  }

  func changes(from old: GuardianStatus, to new: GuardianStatus, now: Int) -> [AppNotification] {
    if old.session != .none && new.session == .none {
      return sessionEnded(old, now: now).map { [$0] } ?? []
    }
    if old.passUntil > 0 && new.passUntil == 0 && Self.isRecent(old.passUntil, now) {
      let groups = GroupNames.list(old.passGroups)
      let verb = old.passGroups.count > 1 ? "vuelven" : "vuelve"
      return [AppNotification(id: "pass-ended", title: "Pase terminado",
                              body: "\(groups) \(verb) a bloquearse en unos segundos.")]
    }
    return []
  }

  /// Solo si terminó por la hora (de la sesión o del retraso). Si terminó por
  /// una acción del usuario sin retraso, o por reiniciar, el usuario ya lo sabe.
  func sessionEnded(_ old: GuardianStatus, now: Int) -> AppNotification? {
    let body: String
    if old.session == .timed && (!old.stopPending || old.sessionEnds <= old.stopAt)
        && Self.isRecent(old.sessionEnds, now) {
      body = "Se acabó el tiempo: los sitios se desbloquean en unos segundos."
    } else if old.stopPending && Self.isRecent(old.stopAt, now) {
      body = "Se cumplió el retraso: los sitios se desbloquean en unos segundos."
    } else {
      return nil
    }
    return AppNotification(id: "session-ended", title: "Sesión terminada", body: body)
  }

  /// Una vez por pase, cuando queda 1 minuto (si el pase dura más que eso).
  mutating func passWarning(_ status: GuardianStatus, now: Int) -> AppNotification? {
    let left = status.passUntil - now
    guard status.passMinutes > 1, left > 0, left <= 60, warnedPassUntil != status.passUntil else { return nil }
    warnedPassUntil = status.passUntil
    let groups = GroupNames.list(status.passGroups)
    let verb = status.passGroups.count > 1 ? "vuelven" : "vuelve"
    return AppNotification(id: "pass-warning", title: "Queda 1 minuto de pase",
                           body: "Después, \(groups) \(verb) a bloquearse.")
  }

  /// Una vez por arranque (también si la app se cierra y se vuelve a abrir): la
  /// sesión sin fin empezó poco después de encender el Mac, y hace poco.
  mutating func autostart(_ status: GuardianStatus, now: Int, bootTime: Int) -> AppNotification? {
    let started = status.sessionStarted
    guard status.session == .indefinite, status.autostartAtBoot, announcedBoot != bootTime,
          started >= bootTime, started - bootTime <= Self.autostartWindow,
          now - started <= Self.autostartWindow else { return nil }
    announcedBoot = bootTime
    return AppNotification(id: "autostart", title: "Modo enfoque activado al encender el Mac",
                           body: "Sesión sin fin: termina al apagar el Mac.")
  }

  static func isRecent(_ time: Int, _ now: Int) -> Bool {
    time <= now && now - time <= recent
  }
}
