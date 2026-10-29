#!/bin/zsh -f
# Pruebas de punta a punta de status y status --json.

source ${0:A:h}/assert.zsh
source ${0:A:h}/e2e.zsh

total=$(( $(expected_block | wc -l) / 2 - 1 ))

# json clave   → el valor de esa clave en $OUT, leído con plutil (que valida el JSON)
json() {
  print -r -- "$OUT" > $CASE/status.json
  plutil -extract $1 raw -o - $CASE/status.json
}

section "Texto: sin sesión"
new_case
run_guardian status
assert_status "sale con 0" 0 $ST "$OUT"
assert_eq "dos líneas" $'Sesión: ninguna\nBloqueo: inactivo' "$OUT"

section "Texto: sesión por tiempo, con pase y terminación pendiente"
run_guardian start 25
run_guardian status
assert_eq "sesión, pases y bloqueo" \
  $'Sesión: por tiempo, termina a las 08:25\nPases usados: 0 de 3\nBloqueo: activo ('$total' dominios)' "$OUT"
at_minute 1
run_guardian pass
run_guardian stop
run_guardian status
assert_contains "terminación pendiente" "Terminación pendiente: el bloqueo termina a las 08:06" "$OUT"
assert_contains "pase en curso" "Pase en curso: youtube, hasta las 08:06" "$OUT"
assert_contains "pases usados" "Pases usados: 1 de 3" "$OUT"

section "Texto: la sesión por tiempo acaba antes que el retraso"
new_case
run_guardian start 25
at_minute 23
run_guardian stop
run_guardian status
assert_contains "dice la hora real de fin" "Terminación pendiente: el bloqueo termina a las 08:25" "$OUT"

section "Texto: sesión sin fin"
new_case
run_guardian start
run_guardian status
assert_contains "desde cuándo" "Sesión: sin fin (desde las 08:00)" "$OUT"

section "Muestra la sesión como la dejaría reconcile, sin escribir nada"
new_case
run_guardian start 25
state_inode=$(inode_of $CASE/data/state)
at_minute 30
run_guardian status
assert_contains "la sesión ya terminó" "Sesión: ninguna" "$OUT"
assert_contains "pero hosts aún no cambió" "Bloqueo: activo" "$OUT"
assert_eq "no reescribe el estado" "$state_inode" "$(inode_of $CASE/data/state)"

section "status no espera ni necesita permiso de escritura"
chmod 555 $CASE/data
run_guardian status
assert_status "con la carpeta de datos de solo lectura, funciona" 0 $ST "$OUT"
chmod 755 $CASE/data

section "JSON"
new_case
run_guardian start 50
at_minute 1
run_guardian pass
run_guardian status --json
assert_status "sale con 0" 0 $ST "$OUT"
assert_eq "now" $(( T0 + 60 )) "$(json now)"
assert_eq "session" timed "$(json session)"
assert_eq "session_started" $T0 "$(json session_started)"
assert_eq "session_ends" $(( T0 + 50 * 60 )) "$(json session_ends)"
assert_eq "stop_at" 0 "$(json stop_at)"
assert_eq "pass_until" $(( T0 + 6 * 60 )) "$(json pass_until)"
assert_eq "passes_used" 1 "$(json passes_used)"
assert_eq "passes_max" 3 "$(json passes_max)"
assert_eq "pass_minutes" 5 "$(json pass_minutes)"
assert_eq "pass_groups" youtube "$(json pass_groups.0)"
assert_eq "stop_delay_minutes" 5 "$(json stop_delay_minutes)"
assert_eq "timed_lock" false "$(json timed_lock)"
assert_eq "timed_presets" "25 50 90" "$(json timed_presets.0) $(json timed_presets.1) $(json timed_presets.2)"
assert_eq "autostart_at_boot" true "$(json autostart_at_boot)"
assert_eq "blocking" true "$(json blocking)"
assert_eq "blocked_domains (sin youtube durante el pase)" $(( total - $(grep -c . <<< "$(
  sed 's/#.*//; /^[[:space:]]*$/d' $REPO/blocklists/youtube.txt)") )) "$(json blocked_domains)"

section "JSON sin sesión"
new_case
run_guardian status --json
assert_eq "session" none "$(json session)"
assert_eq "blocking" false "$(json blocking)"

finish
