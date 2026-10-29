/// Nombres para mostrar de los grupos de blocklists/ (los archivos van en minúsculas).
public enum GroupNames {
  static let known = [
    "youtube": "YouTube", "facebook": "Facebook", "instagram": "Instagram",
    "tiktok": "TikTok", "x": "X", "reddit": "Reddit", "threads": "Threads",
    "twitch": "Twitch", "pinterest": "Pinterest", "whatsapp": "WhatsApp",
  ]

  /// "youtube" → "YouTube". Un grupo desconocido, con la primera letra en mayúscula.
  public static func display(_ group: String) -> String {
    known[group] ?? EngineMessage.capitalizingFirst(group)
  }

  /// "YouTube", "YouTube y Facebook", "YouTube, Facebook y X".
  public static func list(_ groups: [String]) -> String {
    let names = groups.map(display)
    guard let last = names.last, names.count > 1 else { return names.first ?? "" }
    return names.dropLast().joined(separator: ", ") + " y " + last
  }
}
