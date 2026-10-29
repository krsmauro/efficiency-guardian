import Foundation

/// Las líneas de texto del menú que no son acciones: el resumen de arriba y la
/// configuración (solo lectura en la v1).
public enum MenuSummary {
  public static func lines(_ result: StatusResult, now: Int, timeZone: TimeZone = .current) -> [String] {
    switch result {
    case .loading:
      return ["Leyendo el estado…"]
    case .notInstalled:
      return ["El motor no está instalado", "Falta \(GuardianCommand.enginePath): ejecuta sudo ./install.sh"]
    case .failed(let message):
      return ["No se pudo leer el estado:"] + message.split(whereSeparator: \.isNewline).map(String.init)
    case .ok(let status):
      return lines(status, now: now, timeZone: timeZone)
    }
  }

  static func lines(_ status: GuardianStatus, now: Int, timeZone: TimeZone) -> [String] {
    let clock = { TimeText.clock($0, timeZone: timeZone) }
    var lines: [String] = []
    switch status.session {
    case .none:
      lines.append("Sin sesión")
    case .indefinite:
      lines.append("Sesión sin fin, desde las \(clock(status.sessionStarted))")
    case .timed:
      let left = TimeText.remaining(status.sessionEnds - now)
      lines.append("Sesión por tiempo: termina a las \(clock(status.sessionEnds)) (quedan \(left))")
    }
    if status.stopPending {
      lines.append("Terminación pendiente: se desbloquea a las \(clock(status.effectiveStopAt))")
    }
    if status.passActive(at: now) {
      lines.append("Pase \(GroupNames.display(status.passGroup)) hasta las \(clock(status.passUntil))")
    }
    if status.session != .none && status.passesMax > 0 {
      lines.append("Pases usados: \(status.passesUsed) de \(status.passesMax)")
    }
    lines.append(blocking(status, now: now))
    return lines
  }

  /// Lo que hay en hosts ahora. Puede ir hasta 30 s por detrás de la sesión:
  /// los vencimientos los aplica reconcile, cada 30 s. Si el pase cubre todos
  /// los grupos que hay, el motor no escribe ningún bloque mientras dura.
  static func blocking(_ status: GuardianStatus, now: Int) -> String {
    switch (status.session != .none, status.blocking) {
    case (true, true): "Bloqueando \(status.blockedDomains) \(status.blockedDomains == 1 ? "dominio" : "dominios")"
    case (true, false) where status.passActive(at: now): "Nada bloqueado durante el pase"
    case (true, false): "Bloqueo: se aplica en menos de 30 s"
    case (false, true): "Bloqueo: se quita en menos de 30 s"
    case (false, false): "Nada bloqueado"
    }
  }

  /// La configuración del motor, para el submenú "Configuración".
  public static func settings(_ status: GuardianStatus) -> [String] {
    let presets = status.timedPresets.map(String.init).joined(separator: ", ")
    return [
      "Sesiones por tiempo: \(presets) min",
      "Candado en sesiones por tiempo: \(yesNo(status.timedLock))",
      "Retraso al terminar: \(status.stopDelayMinutes) min",
      "Sesión sin fin al encender el Mac: \(yesNo(status.autostartAtBoot))",
      "Pases: \(status.passesMax) por sesión, de \(status.passMinutes) min, uno a la vez (\(GroupNames.list(status.passGroups)))",
    ]
  }

  public static let howToChange = [
    "Para cambiarla: sudo nano /usr/local/etc/efficiency-guardian/config",
    "No hace falta reinstalar: el motor la lee en cada comando",
  ]

  static func yesNo(_ value: Bool) -> String {
    value ? "sí" : "no"
  }
}
