import Foundation

/// Los mensajes del motor, listos para mostrar.
///
/// Los errores del motor son líneas como "guardian: error: no quedan pases en
/// esta sesión (3/3)" (ver lib/log.zsh). Se quita el prefijo y la primera letra
/// va en mayúscula: "No quedan pases en esta sesión (3/3)".
public enum EngineMessage {
  static let prefixes = ["guardian: error: ", "guardian: aviso: ", "guardian: "]

  /// El texto limpio, una línea por línea del original, o nil si no hay nada.
  public static func clean(_ text: String) -> String? {
    let lines = text.split(whereSeparator: \.isNewline).map { line in
      var line = String(line)
      if let prefix = prefixes.first(where: { line.hasPrefix($0) }) {
        line.removeFirst(prefix.count)
      }
      return capitalizingFirst(line.trimmingCharacters(in: .whitespaces))
    }.filter { !$0.isEmpty }
    return lines.isEmpty ? nil : lines.joined(separator: "\n")
  }

  static func capitalizingFirst(_ text: String) -> String {
    text.prefix(1).uppercased() + text.dropFirst()
  }
}
