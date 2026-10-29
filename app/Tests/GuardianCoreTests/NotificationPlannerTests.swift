import Testing
@testable import GuardianCore

@Suite("Notificaciones")
struct NotificationPlannerTests {
  /// El Mac arrancó hace mucho: no interviene el aviso del arranque automático.
  let oldBoot = T0 - 86_400

  /// Pasa los estados por un planificador nuevo y devuelve los ids de lo que avisó en el último.
  func ids(_ steps: [(GuardianStatus, Int)], bootTime: Int? = nil) -> [String] {
    var planner = NotificationPlanner()
    var last: [AppNotification] = []
    for (status, now) in steps {
      last = planner.notifications(for: status, now: now, bootTime: bootTime ?? oldBoot)
    }
    return last.map(\.id)
  }

  @Test("Queda 1 minuto de pase: una sola vez")
  func passWarning() throws {
    let s = try indefinite { $0.passUntil = at(5); $0.passesUsed = 1 }
    #expect(ids([(s, at(3))]) == [])
    #expect(ids([(s, at(3)), (s, at(4))]) == ["pass-warning"])
    #expect(ids([(s, at(4)), (s, at(4, seconds: 1))]) == [])
    #expect(ids([(try indefinite { $0.passUntil = at(1); $0.passMinutes = 1 }, T0 + 10)]) == [])
  }

  @Test("Pase terminado, con la sesión en curso")
  func passEnded() throws {
    let during = try indefinite { $0.passUntil = at(5); $0.passesUsed = 1 }
    let after = try indefinite { $0.passesUsed = 1 }
    #expect(ids([(during, at(4, seconds: 59)), (after, at(5, seconds: 1))]) == ["pass-ended"])
    #expect(ids([(during, at(4)), (after, at(30))]) == [], "tras un reposo largo, no avisa")
  }

  @Test("Se cumplió el retraso al terminar")
  func stopExecuted() throws {
    let pending = try indefinite { $0.stopAt = at(15) }
    var planner = NotificationPlanner()
    _ = planner.notifications(for: pending, now: at(14), bootTime: oldBoot)
    let sent = planner.notifications(for: try status(), now: at(15, seconds: 1), bootTime: oldBoot)
    #expect(sent.map(\.id) == ["session-ended"])
    #expect(sent.first?.body.hasPrefix("Se cumplió el retraso") == true)
  }

  @Test("Se acabó el tiempo de la sesión, también con una terminación pendiente más tardía")
  func timeUp() throws {
    for s in [try timed(), try timed { $0.stopAt = at(28) }] {
      var planner = NotificationPlanner()
      _ = planner.notifications(for: s, now: at(24), bootTime: oldBoot)
      let sent = planner.notifications(for: try status(), now: at(25, seconds: 1), bootTime: oldBoot)
      #expect(sent.first?.body.hasPrefix("Se acabó el tiempo") == true)
    }
  }

  @Test("Terminar sin retraso o reiniciar: sin aviso")
  func endedByUser() throws {
    #expect(ids([(try indefinite(), at(3)), (try status(), at(3))]) == [])
    #expect(ids([(try timed(), at(3)), (try status(), at(3))]) == [])
  }

  @Test("Arranque automático: una vez por arranque, solo si es reciente")
  func autostart() throws {
    let boot = T0 - 60
    let s = try indefinite()
    #expect(ids([(s, at(1))], bootTime: boot) == ["autostart"])
    #expect(ids([(s, at(1)), (s, at(2))], bootTime: boot) == [])
    #expect(ids([(s, at(1)), (try indefinite { $0.sessionStarted = at(1) }, at(2))], bootTime: boot) == [],
            "status antes de reconcile da otra hora de inicio: no repite")
    #expect(ids([(s, at(30))], bootTime: boot) == [], "la app se abrió mucho después")
    #expect(ids([(s, at(1))], bootTime: T0 - 3600) == [], "la sesión empezó mucho después del arranque")
    #expect(ids([(try indefinite { $0.autostartAtBoot = false }, at(1))], bootTime: boot) == [])
    #expect(ids([(try timed(), at(1))], bootTime: boot) == [])
  }

  @Test("Arranque automático: no se repite al volver a abrir la app (la app guarda announcedBoot)")
  func autostartAfterRelaunch() throws {
    let boot = T0 - 60
    var first = NotificationPlanner()
    #expect(first.notifications(for: try indefinite(), now: at(1), bootTime: boot).map(\.id) == ["autostart"])
    var reopened = NotificationPlanner(announcedBoot: first.announcedBoot)
    #expect(reopened.notifications(for: try indefinite(), now: at(2), bootTime: boot).isEmpty)
  }
}
