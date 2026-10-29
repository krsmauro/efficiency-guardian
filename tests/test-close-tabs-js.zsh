#!/bin/zsh -f
# Pruebas de close-tabs/match.js, browser.js y run.js (Fase 3), con el JavaScript
# real de osascript pero SIN navegadores: browser.js recorre uno de mentira
# (tests/fake-browser.js). No pide permisos de Automatización.

source ${0:A:h}/assert.zsh

readonly CT=$REPO/close-tabs

# js script_de_prueba argumentos...  → deja la salida en OUT y el código en ST.
js() {
  local test_script=$1
  shift
  OUT=$(osascript -l JavaScript -e "$(<$CT/match.js)" -e "$(<$CT/browser.js)" \
        -e "$(<$REPO/tests/fake-browser.js)" -e "$test_script" "$@" 2>&1)
  ST=$?
}

section "match.js: qué pestañas se cierran (bloqueados: youtube.com, www.youtube.com, m.youtube.com)"
cases=(
  'https://www.youtube.com/watch?v=abc'                 cerrar
  'https://studio.youtube.com/channel/x'                dejar
  'https://www.linkedin.com/feed/'                      dejar
  'https://user@www.youtube.com:443/watch'              cerrar
  'chrome://settings'                                   dejar
  ''                                                    dejar
  'HTTPS://WWW.YOUTUBE.COM/'                            cerrar
  'https://www.youtube.com./'                           cerrar
  'http://youtube.com'                                  cerrar
  'https://m.youtube.com#comentarios'                   cerrar
  'https://music.youtube.com/'                          dejar
  'https://www.youtube.com.otro.com/'                   dejar
  'https://otro.com/?volver=https://www.youtube.com/'   dejar
  'https://www.youtube.com@otro.com/'                   dejar
  'https://otro.com\@www.youtube.com/'                  dejar
  'view-source:https://www.youtube.com/'                dejar
  'about:blank'                                         dejar
  'file:///Users/x/youtube.com'                         dejar
)
urls=()   # los elementos impares de cases
for (( i = 1; i <= $#cases; i += 2 )); do urls+=("$cases[i]"); done
js 'function run(argv) {
  const blocked = new Set(["youtube.com", "www.youtube.com", "m.youtube.com"])
  return argv.map(url => (shouldClose(url, blocked) ? "cerrar" : "dejar")).join("\n")
}' "${urls[@]}"
assert_status "osascript ejecuta match.js" 0 $ST "$OUT"
answers=("${(@f)OUT}")
for (( i = 1; i <= $#cases; i += 2 )); do
  assert_eq "${(qqqq)cases[i]} → $cases[i+1]" "$cases[i+1]" "${answers[(i+1)/2]:-}"
done

section "browser.js: recorre ventanas y pestañas sin tocar las demás"
js 'function run() {
  const yt = "https://www.youtube.com/watch", li = "https://www.linkedin.com/feed/"
  const windows = {
    1: { live: [yt, li, "https://m.youtube.com/", "https://studio.youtube.com/"] },
    2: { live: [yt, yt] },
    3: null,
    4: { live: [li, yt], read: [yt, li] },
  }
  const closed = closeBlockedTabs(fakeApp(windows), new Set(["www.youtube.com", "m.youtube.com"]))
  return JSON.stringify({ closed: closed, windows: windows })
}'
assert_status "sale bien aunque una ventana desaparezca y otra no tenga pestañas" 0 $ST "$OUT"
# Se compara cada parte por separado, para no depender del orden de las claves.
assert_contains "cierra 4 pestañas" '"closed":4' "$OUT"
assert_contains "ventana 1: quedan LinkedIn y YouTube Studio" \
  '"1":{"live":["https://www.linkedin.com/feed/","https://studio.youtube.com/"]}' "$OUT"
assert_eq "ventana 2: cerró sus dos pestañas y con ellas la ventana" "" "${(M)OUT:#*\"2\":*}"
assert_contains "ventana 4: si las pestañas se movieron tras leerlas, no cierra la que no es (YouTube se cerrará en la siguiente vuelta)" \
  '"4":{"live":["https://www.linkedin.com/feed/","https://www.youtube.com/watch"]' "$OUT"

section "run.js: argumentos"
OUT=$(osascript -l JavaScript -e "$(<$CT/match.js)" -e "$(<$CT/browser.js)" -e "$(<$CT/run.js)" \
      com.apple.Safari 2>&1)
assert_status "sin dominios: error (y no le habla al navegador)" 1 $? "$OUT"
assert_contains "lo explica" "uso: <bundle id> <dominio>" "$OUT"

finish
