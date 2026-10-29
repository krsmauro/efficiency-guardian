#!/bin/zsh -f
# Pruebas de punta a punta de shorten: acortar una sesión por tiempo (Fase 6, A).
# Nunca termina antes que el retraso al terminar (5 min). Reloj falso: T0 = 08:00 UTC.

source ${0:A:h}/assert.zsh
source ${0:A:h}/e2e.zsh

section "Con tiempo de sobra, el fin pasa a la hora elegida"
new_case
run_guardian start 50
at_minute 10
run_guardian shorten 25
assert_status "sale con 0" 0 $ST "$OUT"
assert_eq "lo dice" "Sesión acortada a 25 min: termina a las 08:25." "$OUT"
assert_eq "fin a los 25 min" $(( T0 + 25 * 60 )) "$(state_value SESSION_ENDS)"
assert_eq "sin terminación pendiente" 0 "$(state_value STOP_AT)"
at_minute 25
run_guardian reconcile
assert_same_file "minuto 25: termina y hosts vuelve al original" $CASE/original $CASE/hosts

section "Llegaría antes que el retraso: igual que stop (minuto 22 de 50, a 25)"
new_case
run_guardian start 50
at_minute 22
run_guardian shorten 25
assert_status "sale con 0" 0 $ST "$OUT"
assert_contains "lo explica" "A 25 min, terminaría antes que el retraso al terminar." "$OUT"
assert_contains "y dice cómo anularlo" "El bloqueo sigue hasta las 08:27" "$OUT"
assert_eq "terminación pendiente a los 27 min, no a los 25" $(( T0 + 27 * 60 )) "$(state_value STOP_AT)"
assert_eq "el fin no cambia" $(( T0 + 50 * 60 )) "$(state_value SESSION_ENDS)"
run_guardian cancel-stop
assert_eq "Seguir trabajando la anula" 0 "$(state_value STOP_AT)"

section "Justo a la hora del retraso: también igual que stop (como dice el menú de la app)"
new_case
run_guardian start 50
at_minute 20
run_guardian shorten 25
assert_eq "terminación pendiente a los 25 min" $(( T0 + 25 * 60 )) "$(state_value STOP_AT)"

section "La hora elegida ya pasó: igual que stop"
new_case
run_guardian start 50
at_minute 30
run_guardian shorten 25
assert_contains "lo dice" "Ya pasaron 25 min. El bloqueo sigue hasta las 08:35" "$OUT"
at_minute 35
run_guardian reconcile
assert_eq "minuto 35: termina" none "$(state_value SESSION)"

section "Sin retraso (STOP_DELAY_MINUTES=0) y ya pasó: termina ya"
new_case
set_config STOP_DELAY_MINUTES 0
run_guardian start 50
at_minute 30
run_guardian shorten 25
assert_contains "lo dice" "Sesión terminada" "$OUT"
assert_same_file "hosts vuelve al original" $CASE/original $CASE/hosts
assert_eq "y el estado queda sin sesión" "0 0" "$(state_value SESSION_ENDS) $(state_value TIMED_STARTED)"

section "Rechazos, sin tocar nada"
new_case
run_guardian start 25
run_guardian shorten 25
assert_status "a la misma duración" 1 $ST "$OUT"
assert_contains "lo explica" "la sesión dura 25 min: solo se puede acortar a menos" "$OUT"
run_guardian shorten 50
assert_status "a una más larga" 1 $ST "$OUT"
run_guardian stop
cp $CASE/data/state $CASE/state-before
run_guardian shorten 25
assert_status "con una terminación pendiente" 1 $ST "$OUT"
assert_same_file "el estado no cambia" $CASE/state-before $CASE/data/state
new_case
set_config TIMED_LOCK yes
run_guardian start 50
run_guardian shorten 25
assert_status "con candado" 1 $ST "$OUT"
assert_contains "dice hasta cuándo" "sesión con candado: termina a las 08:50" "$OUT"

section "Una sesión sin fin convertida se mide desde la conversión (TIMED_STARTED)"
new_case
run_guardian start
at_minute 60
run_guardian start 50
at_minute 61
run_guardian shorten 25
assert_eq "fin a los 85 min (60 + 25), no a los 25" $(( T0 + 85 * 60 )) "$(state_value SESSION_ENDS)"

section "Estado de antes de la Fase 6 (sin TIMED_STARTED): se mide desde SESSION_STARTED"
new_case
mkdir -p $CASE/data
print -rl -- SESSION=timed SESSION_STARTED=$T0 SESSION_ENDS=$(( T0 + 50 * 60 )) BOOT_ID=boot1 > $CASE/data/state
run_guardian shorten 25
assert_eq "fin a los 25 min" $(( T0 + 25 * 60 )) "$(state_value SESSION_ENDS)"
assert_eq "y guarda TIMED_STARTED" $T0 "$(state_value TIMED_STARTED)"

finish
