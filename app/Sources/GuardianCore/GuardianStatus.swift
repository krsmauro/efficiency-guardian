import Foundation

/// Lo que devuelve `guardian status --json` (ver lib/status-json.zsh).
///
/// Las horas son epoch (segundos desde 1970); 0 significa "no hay". La sesión
/// ya viene como la dejará `reconcile`: si un pase o una sesión vencieron, el
/// motor lo dice aunque hosts aún no haya cambiado. `blocking` y
/// `blockedDomains`, en cambio, son lo que hay en hosts en este instante.
public struct GuardianStatus: Decodable, Equatable, Sendable {
  public enum Session: String, Decodable, Sendable {
    case none, indefinite, timed
  }

  public var now: Int
  public var session: Session
  public var sessionStarted: Int
  public var sessionEnds: Int
  public var stopAt: Int
  public var passUntil: Int
  public var passesUsed: Int
  public var passesMax: Int
  public var passMinutes: Int
  public var passGroups: [String]
  public var stopDelayMinutes: Int
  public var timedLock: Bool
  public var timedPresets: [Int]
  public var autostartAtBoot: Bool
  public var blocking: Bool
  public var blockedDomains: Int

  /// Decodifica la salida del motor. Falla si falta una clave, si un tipo no
  /// coincide o si la sesión no es none, indefinite o timed.
  public static func decode(_ data: Data) throws -> GuardianStatus {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(GuardianStatus.self, from: data)
  }
}

extension GuardianStatus {
  /// Hay un pase en curso a la hora `now`.
  public func passActive(at now: Int) -> Bool {
    passUntil > now
  }

  /// Hay una terminación pendiente ("terminar" con retraso).
  public var stopPending: Bool {
    session != .none && stopAt > 0
  }

  /// La hora a la que termina de verdad una terminación pendiente: `stopAt`, o
  /// el fin de la sesión por tiempo si llega antes (como session_stop_time en el motor).
  public var effectiveStopAt: Int {
    if session == .timed && sessionEnds < stopAt { return sessionEnds }
    return stopAt
  }

  /// Pases que quedan en esta sesión.
  public var passesLeft: Int {
    max(0, passesMax - passesUsed)
  }

  /// La próxima hora de fin (pase, retraso o sesión por tiempo) posterior a
  /// `time`, o nil. A esa hora el estado cambia y la app lo vuelve a leer.
  public func nextDeadline(after time: Int) -> Int? {
    [passUntil, stopAt, session == .timed ? sessionEnds : 0].filter { $0 > time }.min()
  }

  /// ¿Llegó ya la próxima hora de fin? Se cuenta desde la hora del motor al
  /// leer (`now`), no desde cuándo recibió la app la respuesta: si la lectura
  /// cruzara una hora de fin, la app no la vería hasta el sondeo de 30 s.
  public func deadlinePassed(at time: Int) -> Bool {
    nextDeadline(after: now).map { $0 <= time } ?? false
  }
}
