import Foundation

/// Textos de tiempo para la barra de menús y el menú.
public enum TimeText {
  /// Minutos que quedan, redondeando hacia arriba: "47m"; desde 1 hora, "1h05".
  /// Para la sesión por tiempo, que dura minutos u horas.
  public static func remaining(_ seconds: Int) -> String {
    let minutes = max(0, seconds + 59) / 60
    if minutes < 60 { return "\(minutes)m" }
    return "\(minutes / 60)h" + twoDigits(minutes % 60)
  }

  /// Minutos y segundos: "3:12". Para el pase y la terminación pendiente,
  /// que duran pocos minutos.
  public static func countdown(_ seconds: Int) -> String {
    let seconds = max(0, seconds)
    return "\(seconds / 60):" + twoDigits(seconds % 60)
  }

  /// La hora del día, "10:30" (24 h, como el motor), en la zona horaria dada.
  public static func clock(_ epoch: Int, timeZone: TimeZone = .current) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let date = Date(timeIntervalSince1970: TimeInterval(epoch))
    let parts = calendar.dateComponents([.hour, .minute], from: date)
    return twoDigits(parts.hour ?? 0) + ":" + twoDigits(parts.minute ?? 0)
  }

  static func twoDigits(_ value: Int) -> String {
    value < 10 ? "0\(value)" : "\(value)"
  }
}
