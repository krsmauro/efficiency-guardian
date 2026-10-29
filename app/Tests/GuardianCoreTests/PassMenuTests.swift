import Testing
@testable import GuardianCore

@Suite("El pase en el menú")
struct PassMenuTests {
  func pass(_ s: GuardianStatus, now: Int = T0) -> MenuEntry? {
    MenuModel(status: s, now: now, timeZone: utc).pass
  }

  func off(_ title: String, _ group: String = "youtube") -> MenuEntry {
    .action(MenuAction(title, .pass(group), enabled: false))
  }

  @Test("Un solo sitio: una opción, como en la v1")
  func single() throws {
    #expect(pass(try indefinite()) == .action(MenuAction("Pase YouTube, 5 min (quedan 3)", .pass("youtube"))))
    #expect(pass(try status()) == off("Pase YouTube: solo durante una sesión"))
    #expect(pass(try indefinite { $0.passesUsed = 3 }) == off("Pase YouTube: no quedan (3 de 3)"))
    #expect(pass(try indefinite { $0.passesMax = 0 }) == nil)
  }

  @Test("Varios sitios: un submenú, un sitio por opción, con el límite compartido")
  func several() throws {
    let s = try indefinite { $0.passGroups = ["youtube", "reddit", "mi-foro"]; $0.passMinutes = 10; $0.passesUsed = 1 }
    #expect(pass(s) == .submenu(Submenu("Pase, 10 min (quedan 2)", [
      MenuAction("YouTube", .pass("youtube")),
      MenuAction("Reddit", .pass("reddit")),
      MenuAction("Mi-foro", .pass("mi-foro")),
    ])))
    let both = { (change: (inout GuardianStatus) -> Void) in
      try indefinite { $0.passGroups = ["youtube", "reddit"]; change(&$0) }
    }
    #expect(pass(try both { $0.session = .none }) == off("Pase: solo durante una sesión"))
    #expect(pass(try both { $0.passesUsed = 3 }) == off("Pase: no quedan (3 de 3)"))
  }

  @Test("Pase en curso: dice de qué sitio y hasta cuándo")
  func active() throws {
    let s = try indefinite { $0.passGroups = ["youtube", "reddit"]; $0.passGroup = "reddit"; $0.passUntil = at(6) }
    #expect(pass(s, now: at(2)) == off("Pase Reddit: en curso hasta las 08:06", "reddit"))
    #expect(MenuSummary.lines(.ok(s), now: at(2), timeZone: utc).contains("Pase Reddit hasta las 08:06"))
  }

  @Test("Los avisos dicen qué sitio vuelve a bloquearse")
  func notifications() throws {
    var planner = NotificationPlanner()
    let during = try indefinite { $0.passGroups = ["youtube", "reddit"]; $0.passGroup = "reddit"; $0.passUntil = at(5) }
    #expect(planner.notifications(for: during, now: at(4, seconds: 10), bootTime: 0).map(\.body)
            == ["Después, Reddit vuelve a bloquearse."])
    let after = try indefinite { $0.passGroups = ["youtube", "reddit"] }
    #expect(planner.notifications(for: after, now: at(5, seconds: 1), bootTime: 0).map(\.body)
            == ["Reddit vuelve a bloquearse en unos segundos."])
  }
}
