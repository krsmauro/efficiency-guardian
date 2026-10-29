import Foundation
@testable import GuardianCore

// Ayudas compartidas por las pruebas.
//
// Los archivos de Fixtures/ los genera el motor real (tests/test-app-contract.zsh
// comprueba que siguen coincidiendo con su salida). Su reloj falso empieza en
// T0 = 08:00 UTC, así que las horas se comprueban en UTC.

let T0 = 1_800_000_000
let utc = TimeZone(identifier: "UTC")!

/// T0 + minutos.
func at(_ minutes: Int, seconds: Int = 0) -> Int {
  T0 + minutes * 60 + seconds
}

enum FixtureError: Error {
  case missing(String)
}

/// Lee Fixtures/status-<nombre>.json tal como lo escribió el motor.
func fixtureData(_ name: String) throws -> Data {
  guard let url = Bundle.module.url(forResource: "status-\(name)", withExtension: "json",
                                    subdirectory: "Fixtures") else {
    throw FixtureError.missing(name)
  }
  return try Data(contentsOf: url)
}

func fixture(_ name: String) throws -> GuardianStatus {
  try GuardianStatus.decode(fixtureData(name))
}

/// Un estado de prueba: parte de "sin sesión" (con la configuración por
/// defecto) y aplica los cambios.
func status(_ change: (inout GuardianStatus) -> Void = { _ in }) throws -> GuardianStatus {
  var status = try fixture("none")
  change(&status)
  return status
}

/// Sesión sin fin desde T0, con el bloqueo puesto.
func indefinite(_ change: (inout GuardianStatus) -> Void = { _ in }) throws -> GuardianStatus {
  try status {
    $0.session = .indefinite
    $0.sessionStarted = T0
    $0.blocking = true
    $0.blockedDomains = 82
    change(&$0)
  }
}

/// Sesión por tiempo de 25 min desde T0, con el bloqueo puesto.
func timed(_ change: (inout GuardianStatus) -> Void = { _ in }) throws -> GuardianStatus {
  try indefinite {
    $0.session = .timed
    $0.sessionEnds = at(25)
    $0.timedStarted = T0
    change(&$0)
  }
}
