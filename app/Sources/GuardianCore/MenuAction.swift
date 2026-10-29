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

/// Un submenú: "Nueva sesión ▸", "Alargar ▸"… Si no se puede usar va
/// desactivado, sin opciones, y su título dice por qué.
public struct Submenu: Equatable, Sendable {
  public let title: String
  public var items: [MenuAction]
  public let enabled: Bool

  public init(_ title: String, _ items: [MenuAction], enabled: Bool = true) {
    self.title = title
    self.items = items
    self.enabled = enabled
  }

  mutating func disableItems() {
    for index in items.indices { items[index].enabled = false }
  }
}

/// Lo que según el estado es una opción o un submenú: el pase es una opción con
/// un solo sitio y un submenú con varios.
public enum MenuEntry: Equatable, Sendable {
  case action(MenuAction)
  case submenu(Submenu)

  mutating func disable() {
    switch self {
    case .action(var action):
      action.enabled = false
      self = .action(action)
    case .submenu(var submenu):
      submenu.disableItems()
      self = .submenu(submenu)
    }
  }
}
