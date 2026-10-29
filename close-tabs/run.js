// Punto de entrada para osascript. close-tabs.zsh lo llama así:
//   osascript -l JavaScript -e "$(<match.js)" -e "$(<browser.js)" -e "$(<run.js)" \
//     <bundle id> <dominio>...
// osascript escribe lo que devuelve run: el número de pestañas cerradas.

function run(argv) {
  if (argv.length < 2) throw new Error('uso: <bundle id> <dominio>...')
  const app = Application(argv[0])
  // Nunca hablarle a un navegador cerrado: eso lo abriría. close-tabs.zsh ya
  // lo comprobó; se repite por si se cerró entretanto.
  if (!app.running()) return 0
  const blocked = new Set(argv.slice(1).map(domain => domain.toLowerCase()))
  return closeBlockedTabs(app, blocked)
}
