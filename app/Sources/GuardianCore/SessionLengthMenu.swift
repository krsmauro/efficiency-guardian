import Foundation

/// "Alargar ▸" y "Acortar ▸" con una sesión por tiempo (Fase 6, A; D16).
///
/// Las dos eligen cuánto dura la sesión en total, contado desde que empezó la
/// parte por tiempo (`timedStarted`), con las duraciones de TIMED_PRESETS (el
/// motor solo admite esas). Los textos dicen la hora de fin, no cuánto falta,
/// para que el menú no cambie cada segundo (ver MenuSnapshot).
public enum SessionLengthMenu {
  /// "a 90 min (hasta las 14:45)" por cada duración mayor que la actual, y
  /// "Sin fin", que siempre está: así alargar no tiene tope. Con candado se
  /// puede alargar, pero "Sin fin" va desactivado: sería saltarse el candado.
  static func extend(_ status: GuardianStatus, timeZone: TimeZone) -> Submenu {
    let current = status.sessionEnds - status.timedStarted
    let longer = status.timedPresets.filter { $0 * 60 > current }.map { minutes in
      let end = TimeText.clock(status.timedStarted + minutes * 60, timeZone: timeZone)
      return MenuAction("a \(minutes) min (hasta las \(end))", .extend(minutes))
    }
    return Submenu("Alargar", longer + [endless(status, timeZone: timeZone)])
  }

  static func endless(_ status: GuardianStatus, timeZone: TimeZone) -> MenuAction {
    guard status.timedLock else { return MenuAction("Sin fin", .extendEndless) }
    let ends = TimeText.clock(status.sessionEnds, timeZone: timeZone)
    return MenuAction("Sin fin: con candado hasta las \(ends)", .extendEndless, enabled: false)
  }

  /// Solo las duraciones menores que la actual; nil si no hay ninguna. Con
  /// candado, desactivado y dice hasta cuándo.
  static func shorten(_ status: GuardianStatus, now: Int, timeZone: TimeZone) -> Submenu? {
    let current = status.sessionEnds - status.timedStarted
    let shorter = status.timedPresets.filter { $0 * 60 < current }
    guard !shorter.isEmpty else { return nil }
    if status.timedLock {
      let ends = TimeText.clock(status.sessionEnds, timeZone: timeZone)
      return Submenu("Acortar: con candado hasta las \(ends)", [], enabled: false)
    }
    return Submenu("Acortar", shorter.map { option($0, status, now: now, timeZone: timeZone) })
  }

  /// "a 25 min (termina a las 14:20)". Si esa hora llega antes que el retraso
  /// al terminar, el motor deja una terminación pendiente (como "Terminar"):
  /// acortar nunca sirve para saltarse el retraso.
  static func option(_ minutes: Int, _ status: GuardianStatus, now: Int, timeZone: TimeZone) -> MenuAction {
    let target = status.timedStarted + minutes * 60
    let delay = status.stopDelayMinutes
    let title: String
    if target > now + delay * 60 {
      title = "a \(minutes) min (termina a las \(TimeText.clock(target, timeZone: timeZone)))"
    } else if delay > 0 {
      title = "a \(minutes) min (termina en \(delay) min: el retraso al terminar)"
    } else {
      title = "a \(minutes) min (termina ahora)"
    }
    return MenuAction(title, .shorten(minutes))
  }
}
