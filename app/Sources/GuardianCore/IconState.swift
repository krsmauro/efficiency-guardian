/// Lo que muestra la barra de menús: un SF Symbol y, a veces, un texto corto.
///
/// Si pasan varias cosas a la vez, manda la primera: error, pase en curso,
/// terminación pendiente, sesión por tiempo, sesión sin fin, nada.
public struct IconState: Equatable, Sendable {
  public let symbol: String
  public let text: String?

  public init(symbol: String, text: String? = nil) {
    self.symbol = symbol
    self.text = text
  }

  public static let loading = IconState(symbol: "ellipsis")
  public static let problem = IconState(symbol: "exclamationmark.triangle")
  public static let idle = IconState(symbol: "lock.open")
  public static let locked = IconState(symbol: "lock.fill")

  public static func from(_ result: StatusResult, now: Int) -> IconState {
    switch result {
    case .loading: return .loading
    case .notInstalled, .failed: return .problem
    case .ok(let status): return from(status, now: now)
    }
  }

  static func from(_ status: GuardianStatus, now: Int) -> IconState {
    if status.passActive(at: now) {
      return IconState(symbol: "ticket", text: TimeText.countdown(status.passUntil - now))
    }
    if status.stopPending {
      return IconState(symbol: "hourglass", text: TimeText.countdown(status.effectiveStopAt - now))
    }
    switch status.session {
    case .timed: return IconState(symbol: "lock.fill", text: TimeText.remaining(status.sessionEnds - now))
    case .indefinite: return .locked
    case .none: return .idle
    }
  }
}
