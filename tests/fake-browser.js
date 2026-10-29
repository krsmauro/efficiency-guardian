// Navegador de mentira para probar close-tabs/browser.js con osascript, sin
// abrir ningún navegador ni pedir permisos. Lo usa tests/test-close-tabs-js.zsh.
//
// Imita lo que browser.js usa de JXA:
//   app.windows.id()          los id de las ventanas
//   app.windows.byId(id)      una ventana
//   win.tabs.url()            todas las URL de la ventana
//   win.tabs[i].url()/close() la pestaña que está en la posición i AL USARLA
//
// windows es un objeto { id: ventana }, y cada ventana es:
//   null                  una ventana sin pestañas (leerla da error, como Ajustes)
//   { live: [urls] }      sus pestañas
//   { live, read: [urls] } win.tabs.url() devuelve "read" en vez de "live": simula
//                         que el usuario movió pestañas justo después de leerlas
function fakeApp(windows) {
  const live = id => {
    if (!windows[id]) throw new Error('la ventana no existe o no tiene pestañas')
    return windows[id].live
  }
  const tab = (id, i) => ({
    url: () => live(id)[i],
    close: () => {
      live(id).splice(i, 1)
      if (live(id).length === 0) delete windows[id]  // la última pestaña cierra la ventana
    },
  })
  const win = id => ({
    get tabs() {
      const tabs = { url: () => (windows[id] && windows[id].read) || live(id).slice() }
      for (let i = 0; i < live(id).length; i++) tabs[i] = tab(id, i)
      return tabs
    },
  })
  return { windows: { id: () => Object.keys(windows).map(Number), byId: win } }
}
