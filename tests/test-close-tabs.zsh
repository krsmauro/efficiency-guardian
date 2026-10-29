#!/bin/zsh -f
# Pruebas de close-tabs/close-tabs.zsh (Fase 3) con osascript y lsappinfo de
# mentira: qué navegadores llama, con qué dominios y cómo informa los errores.
# (El JavaScript se prueba aparte, en test-close-tabs-js.zsh.)

source ${0:A:h}/assert.zsh
source ${0:A:h}/fake-commands.zsh

# Los marcadores se escriben a mano, para no comprobar el módulo contra sí mismo.
begin='# >>> efficiency-guardian (gestionado automáticamente; no editar a mano) >>>'
end='# <<< efficiency-guardian <<<'
local_lines=$'127.0.0.1\tlocalhost\n::1 localhost\n'
blocked=$local_lines$'\n'"$begin"$'\n0.0.0.0 www.youtube.com\n:: www.youtube.com\n0.0.0.0 youtube.com\n:: youtube.com\n'"$end"$'\n'

section "Sin bloqueo"
new_case "$local_lines"$'0.0.0.0 manual.com\n' com.brave.Browser
run_close_tabs
assert_status "sale con 0" 0 $ST "$ERR"
assert_eq "no llama a ningún navegador (las líneas manuales no cuentan)" "" "$CALLS"
assert_eq "no dice nada" "" "$OUT$ERR"

section "Con bloqueo, sin navegadores abiertos"
new_case "$blocked"
run_close_tabs
assert_status "sale con 0" 0 $ST "$ERR"
assert_eq "no llama a ningún navegador: hablarle a uno cerrado lo abriría" "" "$CALLS"

section "Con bloqueo y dos navegadores abiertos"
new_case "$blocked" com.brave.Browser com.apple.Safari
print 2 > $F/out-com.brave.Browser
run_close_tabs
assert_status "sale con 0" 0 $ST "$ERR"
assert_eq "llama a cada uno con los 3 scripts y los dominios del bloque, en orden" \
  $'3 com.apple.Safari www.youtube.com youtube.com\n3 com.brave.Browser www.youtube.com youtube.com' "$CALLS"
assert_eq "dice cuántas cerró, y nada si fueron 0" "close-tabs: Brave: 2 pestañas cerradas" "$OUT"
# (Se leen en variables: "zsh -n" lee los $(<archivo) que van como argumentos.)
expected=$(<$REPO/close-tabs/match.js) got=$(<$F/script-1)
assert_eq "pasa match.js tal cual" "$expected" "$got"
expected=$(<$REPO/close-tabs/run.js) got=$(<$F/script-3)
assert_eq "pasa run.js el último (define run)" "$expected" "$got"

section "Sin permiso de Automatización en un navegador"
new_case "$blocked" com.apple.Safari com.google.Chrome
print 'execution error: Error: Not authorized to send Apple events to Safari. (-1743)' > $F/out-com.apple.Safari
print 1 > $F/status-com.apple.Safari
run_close_tabs
assert_status "sale con 1" 1 $ST "$ERR"
assert_contains "muestra el error de osascript" "close-tabs: Safari: execution error" "$ERR"
assert_contains "explica dónde dar el permiso" "falta el permiso de Automatización" "$ERR"
assert_contains "sigue con el siguiente navegador" "3 com.google.Chrome" "$CALLS"

section "Respuesta inesperada"
new_case "$blocked" com.vivaldi.Vivaldi
print 'hola' > $F/out-com.vivaldi.Vivaldi
run_close_tabs
assert_status "sale con 1" 1 $ST "$ERR"
assert_contains "lo dice" "Vivaldi: respuesta inesperada: hola" "$ERR"

section "Errores del hosts: no cierra nada"
new_case "$local_lines$begin"$'\n0.0.0.0 x.com\n' org.chromium.Thorium
run_close_tabs
assert_status "marcadores dañados: sale con 1" 1 $ST "$ERR"
assert_contains "lo explica" "marcadores" "$ERR"
assert_eq "no llama a ningún navegador" "" "$CALLS"
new_case "$blocked" org.chromium.Thorium
rm $T_TMP/hosts
run_close_tabs
assert_status "sin hosts: sale con 1" 1 $ST "$ERR"
assert_contains "lo explica" "no se puede leer $T_TMP/hosts" "$ERR"

finish
