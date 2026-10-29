import Foundation

/// Vigila una carpeta y llama a `onChange` (en el hilo principal) cuando cambia
/// algo dentro.
///
/// Se vigila la carpeta y no el archivo de estado porque el motor lo reemplaza
/// con "temporal + mv": el archivo vigilado dejaría de ser el actual.
/// Si la carpeta no existe (motor sin instalar), el inicializador devuelve nil.
@MainActor
final class StateWatcher {
  private let source: DispatchSourceFileSystemObject

  init?(path: String, onChange: @escaping @MainActor () -> Void) {
    let descriptor = open(path, O_EVTONLY)
    guard descriptor >= 0 else { return nil }
    source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: descriptor, eventMask: [.write, .delete, .rename], queue: .main)
    source.setEventHandler {
      MainActor.assumeIsolated { onChange() }
    }
    source.setCancelHandler { close(descriptor) }
    source.resume()
  }

  isolated deinit {
    source.cancel()
  }
}
