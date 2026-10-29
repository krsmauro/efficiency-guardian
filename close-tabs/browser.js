// Cierra, en UN navegador, las pestañas de dominios bloqueados (usa match.js).
//
// Sirve para Safari y para los Chromium (Chrome, Brave, Vivaldi y Thorium): los
// cinco usan los mismos nombres de AppleScript (windows, tabs, url, close).
// Cada lectura o cierre es un "evento de Apple" que macOS solo permite con el
// permiso de Automatización para ese navegador.

// closeBlockedTabs(app, blocked): cuántas pestañas cerró.
function closeBlockedTabs(app, blocked) {
  let closed = 0
  for (const windowId of app.windows.id()) {
    // Por id y no por posición: la posición cambia cada vez que se usa una ventana.
    const win = app.windows.byId(windowId)
    let urls
    try {
      urls = win.tabs.url()   // todas las URL de la ventana en un solo evento
    } catch (e) {
      continue                // ventana sin pestañas (por ejemplo, Ajustes) o ya cerrada
    }
    // De la última a la primera: cerrar una pestaña no mueve las anteriores.
    for (let i = urls.length - 1; i >= 0; i--) {
      if (!shouldClose(urls[i], blocked)) continue
      try {
        const tab = win.tabs[i]
        // Se vuelve a leer justo antes de cerrar: si el usuario movió pestañas
        // entretanto, en esa posición puede haber otra, y esa no se toca.
        if (shouldClose(tab.url(), blocked)) {
          tab.close()
          closed++
        }
      } catch (e) {
        // La pestaña o la ventana ya no existe (cerrar la última pestaña cierra la ventana).
      }
    }
  }
  return closed
}
