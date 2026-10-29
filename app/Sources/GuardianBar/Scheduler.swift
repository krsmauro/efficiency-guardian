import AppKit
import GuardianCore

/// Decide cuándo volver a leer el estado (ver "Cuándo se vuelve a leer" en la
/// especificación de la Fase 5):
/// - cada segundo avanza la cuenta atrás;
/// - al llegar una hora de fin (pase, retraso, sesión), al instante;
/// - cuando cambia la carpeta de datos del motor (Atajos, reconcile), al instante;
/// - al despertar el Mac;
/// - y cada 30 s por si acaso.
@MainActor
final class Scheduler {
  static let dataDirectory = "/var/db/efficiency-guardian"
  static let pollSeconds = 30

  private weak var model: AppModel?
  private var timer: Timer?
  private var watcher: StateWatcher?
  private var pendingRead: Task<Void, Never>?
  private var wakeObserver: NSObjectProtocol?

  init(model: AppModel) {
    self.model = model
    // En el modo .common el temporizador sigue con el menú abierto.
    let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.everySecond() }
    }
    RunLoop.main.add(timer, forMode: .common)
    self.timer = timer
    watchDataDirectory()
    wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.readSoon() }
    }
  }

  private func everySecond() {
    guard let model else { return }
    model.tick()
    if model.reading { return }
    let deadlinePassed = model.result.status?.deadlinePassed(at: model.now) ?? false
    if deadlinePassed || model.secondsSinceRead >= Self.pollSeconds {
      if watcher == nil { watchDataDirectory() }
      Task { await model.refresh() }
    }
  }

  /// Si la carpeta aún no existe (motor sin instalar), se reintenta en cada sondeo.
  private func watchDataDirectory() {
    watcher = StateWatcher(path: Self.dataDirectory) { [weak self] in self?.readSoon() }
  }

  /// Lee el estado medio segundo después del último aviso: el motor escribe el
  /// estado y después hosts, y así la lectura los ve a los dos.
  private func readSoon() {
    pendingRead?.cancel()
    pendingRead = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(500))
      guard !Task.isCancelled, let model = self?.model else { return }
      await model.refresh()
    }
  }
}
