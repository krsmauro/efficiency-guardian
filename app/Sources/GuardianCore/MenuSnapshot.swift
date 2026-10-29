import Foundation

/// Todo lo que dibuja el menú, ya calculado como texto.
///
/// La app solo lo vuelve a publicar cuando cambia: cada vez que SwiftUI
/// redibuja el menú de MenuBarExtra, macOS cierra el submenú abierto (fallo de
/// la verificación 5.6). Por eso no guarda la hora ni el estado completo (su
/// `now` cambia en cada lectura): solo los textos y si están activos. La cuenta
/// atrás de cada segundo va en el ícono (IconState), que se dibuja aparte.
public struct MenuSnapshot: Equatable, Sendable {
  /// Las líneas de resumen de arriba.
  public let summary: [String]
  /// Las acciones; nil si no se pudo leer el estado.
  public let menu: MenuModel?
  /// El submenú "Configuración"; vacío si no se pudo leer el estado.
  public let settings: [String]
  /// "Reintentar": si falló la lectura o falta el motor (no mientras se lee).
  public let offersRetry: Bool

  public init(result: StatusResult, now: Int, busy: Bool, timeZone: TimeZone = .current) {
    summary = MenuSummary.lines(result, now: now, timeZone: timeZone)
    menu = result.status.map { MenuModel(status: $0, now: now, busy: busy, timeZone: timeZone) }
    settings = result.status.map(MenuSummary.settings) ?? []
    offersRetry = result.status == nil && result != .loading
  }
}
