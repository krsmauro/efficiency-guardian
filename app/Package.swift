// swift-tools-version: 6.2
// La app de barra de menús (Fase 5). Ver docs/fases/fase-5-app-barra-de-menus.md.
//
//   GuardianCore  la lógica que decide qué mostrar; no toca el sistema y tiene pruebas
//   GuardianBar   la app: vistas, ejecutar el motor, notificaciones, ítem de inicio
//
// Compilar la app: zsh app/build.zsh. Pruebas: swift test --package-path app.
import PackageDescription

let package = Package(
  name: "EfficiencyGuardian",
  platforms: [.macOS(.v26)],
  targets: [
    .target(name: "GuardianCore"),
    .executableTarget(name: "GuardianBar", dependencies: ["GuardianCore"]),
    .testTarget(
      name: "GuardianCoreTests",
      dependencies: ["GuardianCore"],
      resources: [.copy("Fixtures")]
    ),
  ]
)
