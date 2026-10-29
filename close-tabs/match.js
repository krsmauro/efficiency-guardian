// Decide si una pestaña se cierra. Solo se cierra si es una página web (http o
// https) y su host coincide EXACTAMENTE con un dominio bloqueado, igual que hace
// /etc/hosts. Por ejemplo, con www.youtube.com bloqueado, studio.youtube.com no
// se cierra.
//
// No usa nada del navegador: tests/test-close-tabs-js.zsh lo prueba solo.

// hostOf(url): el host en minúsculas, o '' si la URL no es http(s).
function hostOf(url) {
  // La autoridad termina en / ? # o \ (los navegadores tratan \ como /).
  const found = /^https?:\/\/([^\/\\?#]*)/i.exec(String(url || ''))
  if (!found) return ''
  let host = found[1]
  host = host.slice(host.lastIndexOf('@') + 1)   // quita "usuario:clave@"
  host = host.replace(/:[0-9]*$/, '')            // quita el puerto
  return host.replace(/\.$/, '').toLowerCase()   // "youtube.com." es el mismo host
}

// shouldClose(url, blocked): true si hay que cerrar la pestaña.
// blocked es un Set de dominios en minúsculas.
function shouldClose(url, blocked) {
  const host = hostOf(url)
  return host !== '' && blocked.has(host)
}
