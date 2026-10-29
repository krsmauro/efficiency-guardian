#!/bin/zsh -f
# Pruebas de punta a punta de start y start <minutos>: sesiones sin fin, por
# tiempo y la conversión de una en otra (supuesto S2). Reloj falso: T0 = 08:00 UTC.

source ${0:A:h}/assert.zsh
source ${0:A:h}/e2e.zsh

section "start sin sesión: sesión sin fin"
new_case
run_guardian start
assert_status "sale con 0" 0 $ST "$OUT"
assert_eq "sin fin" indefinite "$(state_value SESSION)"
assert_eq "empieza ahora" $T0 "$(state_value SESSION_STARTED)"
assert_eq "contador a 0" 0 "$(state_value PASSES_USED)"
assert_true "bloquea youtube.com" blocked youtube.com

section "Un segundo start no reinicia nada"
run_guardian pass
at_minute 2
cp $CASE/data/state $CASE/state-before
run_guardian start
assert_contains "lo dice" "Ya había una sesión" "$OUT"
assert_same_file "el estado no cambia" $CASE/state-before $CASE/data/state

section "start 50 sin sesión: sesión por tiempo"
new_case
run_guardian start 50
assert_status "sale con 0" 0 $ST "$OUT"
assert_contains "dice la hora de fin" "termina a las 08:50" "$OUT"
assert_eq "por tiempo" timed "$(state_value SESSION)"
assert_eq "fin en 50 min" $(( T0 + 50 * 60 )) "$(state_value SESSION_ENDS)"
at_minute 49
run_guardian reconcile
assert_eq "minuto 49: sigue" timed "$(state_value SESSION)"
assert_true "minuto 49: sigue bloqueado" blocked youtube.com
at_minute 50
run_guardian reconcile
assert_eq "minuto 50: termina" none "$(state_value SESSION)"
assert_same_file "minuto 50: hosts vuelve al original" $CASE/original $CASE/hosts

section "start 37: fuera de TIMED_PRESETS"
new_case
run_guardian start 37
assert_status "error" 1 $ST "$OUT"
assert_contains "dice cuáles valen" "TIMED_PRESETS: 25, 50, 90" "$OUT"
assert_same_file "hosts intacto" $CASE/original $CASE/hosts
assert_false "sin estado" test -e $CASE/data/state

section "S2: start 25 con una sesión sin fin la convierte"
new_case
run_guardian start
run_guardian pass
at_minute 2
run_guardian start 25
assert_status "sale con 0" 0 $ST "$OUT"
assert_contains "dice la hora de fin y los pases" "termina a las 08:27. Pases usados: 1 de 3" "$OUT"
assert_eq "por tiempo" timed "$(state_value SESSION)"
assert_eq "fin en 25 min desde ahora" $(( T0 + 27 * 60 )) "$(state_value SESSION_ENDS)"
assert_eq "conserva los pases usados" 1 "$(state_value PASSES_USED)"
assert_eq "conserva el pase en curso" $(( T0 + 5 * 60 )) "$(state_value PASS_UNTIL)"
assert_eq "conserva el inicio" $T0 "$(state_value SESSION_STARTED)"

section "S2: con otra por tiempo en curso, error"
cp $CASE/data/state $CASE/state-before
run_guardian start 50
assert_status "error" 1 $ST "$OUT"
assert_contains "dice cuándo termina la actual" "termina a las 08:27" "$OUT"
assert_same_file "el estado no cambia" $CASE/state-before $CASE/data/state

section "S2: convertir no sirve para saltarse el retraso al terminar"
new_case
set_config TIMED_PRESETS 1,25
run_guardian start
run_guardian start 1
assert_eq "termina tras el retraso (5 min), no en 1" $(( T0 + 5 * 60 )) "$(state_value SESSION_ENDS)"

section "S2: convertir anula una terminación pendiente"
new_case
run_guardian start
run_guardian stop
run_guardian start 50
assert_eq "sin terminación pendiente" 0 "$(state_value STOP_AT)"
at_minute 10
run_guardian reconcile
assert_eq "a los 10 min sigue" timed "$(state_value SESSION)"

finish
