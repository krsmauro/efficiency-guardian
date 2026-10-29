import Foundation

/// La hora actual y la hora de arranque del Mac, en epoch (segundos desde 1970),
/// como las usa el motor.
enum SystemClock {
  static var now: Int {
    Int(Date().timeIntervalSince1970)
  }

  /// Cuándo arrancó el Mac (kern.boottime); 0 si no se pudo leer. No cambia
  /// mientras la app está abierta: ni dormir ni despertar el Mac lo cambian.
  static let bootTime: Int = {
    var mib = [CTL_KERN, KERN_BOOTTIME]
    var value = timeval()
    var size = MemoryLayout<timeval>.size
    guard sysctl(&mib, 2, &value, &size, nil, 0) == 0 else { return 0 }
    return Int(value.tv_sec)
  }()
}
