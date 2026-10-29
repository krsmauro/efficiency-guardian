import Foundation

/// El pase en el menú (D5; Fase 6, B). Cada pase desbloquea un sitio de
/// PASS_GROUPS, y el límite de pases es compartido entre todos.
/// - Con un solo sitio, una opción, como en la v1: "Pase YouTube, 5 min (quedan 3)".
/// - Con varios, un submenú: "Pase, 5 min (quedan 3) ▸ YouTube / Reddit".
/// - Si no se puede usar, una opción desactivada que dice por qué.
/// - nil sin pases (PASS_MAX_PER_SESSION=0).
public enum PassMenu {
  static func entry(_ status: GuardianStatus, now: Int, timeZone: TimeZone) -> MenuEntry? {
    guard status.passesMax > 0, let first = status.passGroups.first else { return nil }
    let single = status.passGroups.count == 1
    let name = single ? "Pase \(GroupNames.display(first))" : "Pase"
    let disabled = { (title: String, group: String) in
      MenuEntry.action(MenuAction(title, .pass(group), enabled: false))
    }

    if status.session == .none {
      return disabled("\(name): solo durante una sesión", first)
    }
    if status.passActive(at: now) {
      let until = TimeText.clock(status.passUntil, timeZone: timeZone)
      return disabled("Pase \(GroupNames.display(status.passGroup)): en curso hasta las \(until)", status.passGroup)
    }
    if status.passesLeft == 0 {
      return disabled("\(name): no quedan (\(status.passesUsed) de \(status.passesMax))", first)
    }
    let details = "\(status.passMinutes) min (quedan \(status.passesLeft))"
    if single {
      return .action(MenuAction("\(name), \(details)", .pass(first)))
    }
    return .submenu(Submenu("Pase, \(details)", status.passGroups.map {
      MenuAction(GroupNames.display($0), .pass($0))
    }))
  }
}
