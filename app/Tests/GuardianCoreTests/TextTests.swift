import Foundation
import Testing
@testable import GuardianCore

@Suite("Textos: tiempo, grupos y mensajes del motor")
struct TextTests {
  @Test("Minutos que quedan, redondeando hacia arriba")
  func remaining() {
    #expect(TimeText.remaining(47 * 60) == "47m")
    #expect(TimeText.remaining(46 * 60 + 1) == "47m")
    #expect(TimeText.remaining(30) == "1m")
    #expect(TimeText.remaining(0) == "0m")
    #expect(TimeText.remaining(-90) == "0m")
    #expect(TimeText.remaining(60 * 60) == "1h00")
    #expect(TimeText.remaining(65 * 60) == "1h05")
    #expect(TimeText.remaining(90 * 60) == "1h30")
  }

  @Test("Cuenta atrás en minutos y segundos")
  func countdown() {
    #expect(TimeText.countdown(192) == "3:12")
    #expect(TimeText.countdown(300) == "5:00")
    #expect(TimeText.countdown(9) == "0:09")
    #expect(TimeText.countdown(-5) == "0:00")
  }

  @Test("Hora del día")
  func clock() {
    #expect(TimeText.clock(T0, timeZone: utc) == "08:00")
    #expect(TimeText.clock(at(25), timeZone: utc) == "08:25")
    #expect(TimeText.clock(at(16 * 60 + 5), timeZone: utc) == "00:05")
  }

  @Test("Nombres de los grupos")
  func groups() {
    #expect(GroupNames.display("youtube") == "YouTube")
    #expect(GroupNames.display("whatsapp") == "WhatsApp")
    #expect(GroupNames.display("mastodon") == "Mastodon")
    #expect(GroupNames.list(["youtube"]) == "YouTube")
    #expect(GroupNames.list(["youtube", "facebook"]) == "YouTube y Facebook")
    #expect(GroupNames.list(["youtube", "facebook", "x"]) == "YouTube, Facebook y X")
    #expect(GroupNames.list([]) == "")
  }

  @Test("Mensajes del motor sin prefijo")
  func engineMessage() {
    #expect(EngineMessage.clean("guardian: error: no quedan pases en esta sesión (3/3)\n")
            == "No quedan pases en esta sesión (3/3)")
    #expect(EngineMessage.clean("guardian: aviso: algo\nguardian: error: otra cosa") == "Algo\nOtra cosa")
    #expect(EngineMessage.clean("Sesión sin fin iniciada. 82 dominios bloqueados.\n")
            == "Sesión sin fin iniciada. 82 dominios bloqueados.")
    #expect(EngineMessage.clean("  \n\n") == nil)
  }
}
