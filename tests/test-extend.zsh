#!/bin/zsh -f
# Pruebas de punta a punta de extend (Fase 6, A): "extend <min>" hace que la
# sesión por tiempo dure eso en total; "extend", sin minutos, la pasa a sin fin.
# Reloj falso: T0 = 08:00 UTC.

source ${0:A:h}/assert.zsh
source ${0:A:h}/e2e.zsh

section "Dura eso en total, contado desde que empezó (no desde ahora): de 25 a 90"
new_case
run_guardian start 25
at_minute 10
run_guardian extend 90
assert_status "sale con 0" 0 $ST "$OUT"
assert_eq "lo dice" "Sesión alargada a 90 min: termina a las 09:30." "$OUT"
assert_eq "fin a los 90 min" $(( T0 + 90 * 60 )) "$(state_value SESSION_ENDS)"
assert_eq "la parte por tiempo empezó igual" $T0 "$(state_value TIMED_STARTED)"
at_minute 26
run_guardian reconcile
assert_eq "minuto 26: sigue" timed "$(state_value SESSION)"
assert_true "minuto 26: sigue bloqueado" blocked youtube.com

section "Con candado, también: es más enfoque"
new_case
set_config TIMED_LOCK yes
run_guardian start 25
run_guardian extend 50
assert_status "sale con 0" 0 $ST "$OUT"
assert_eq "fin a los 50 min" $(( T0 + 50 * 60 )) "$(state_value SESSION_ENDS)"

section "Sin minutos: pasa a sin fin y conserva los pases"
new_case
run_guardian start 25
at_minute 10
run_guardian pass
run_guardian extend
assert_status "sale con 0" 0 $ST "$OUT"
assert_contains "lo dice" "La sesión ahora es sin fin" "$OUT"
assert_contains "y cuántos pases lleva" "Pases usados: 1 de 3." "$OUT"
assert_eq "sin fin y sin hora de fin" "indefinite 0 0" \
  "$(state_value SESSION) $(state_value SESSION_ENDS) $(state_value TIMED_STARTED)"
assert_eq "conserva cuándo empezó" $T0 "$(state_value SESSION_STARTED)"
assert_eq "el pase en curso sigue" youtube "$(state_value PASS_GROUP)"
at_minute 200
run_guardian reconcile
assert_eq "minuto 200: sigue" indefinite "$(state_value SESSION)"
assert_true "minuto 200: sigue bloqueado" blocked youtube.com
run_guardian stop
assert_contains "se termina con stop, tras el retraso" "El bloqueo sigue hasta las 11:25" "$OUT"

section "Rechazos, sin tocar nada"
new_case
run_guardian start 50
cp $CASE/data/state $CASE/state-before
run_guardian extend 37
assert_status "una duración fuera de TIMED_PRESETS" 1 $ST "$OUT"
assert_contains "dice cuáles valen" "TIMED_PRESETS: 25, 50, 90" "$OUT"
run_guardian extend 50
assert_status "a la misma duración" 1 $ST "$OUT"
assert_contains "lo explica" "la sesión dura 50 min: solo se puede alargar a más" "$OUT"
run_guardian extend 25
assert_status "a una más corta" 1 $ST "$OUT"
assert_same_file "el estado no cambia" $CASE/state-before $CASE/data/state
run_guardian stop
cp $CASE/data/state $CASE/state-before
for args in 'extend 90' 'extend'; do
  run_guardian ${=args}
  assert_status "$args, con una terminación pendiente" 1 $ST "$OUT"
  assert_contains "$args: dice qué hacer" "anúlala primero (cancel-stop)" "$OUT"
done
assert_same_file "el estado no cambia" $CASE/state-before $CASE/data/state
new_case
set_config TIMED_LOCK yes
run_guardian start 25
run_guardian extend
assert_status "sin fin, con candado: sería saltárselo" 1 $ST "$OUT"
assert_contains "dice hasta cuándo" "sesión con candado: termina a las 08:25" "$OUT"
assert_eq "sigue por tiempo" timed "$(state_value SESSION)"
new_case
for args in 'extend 25' 'extend'; do
  run_guardian ${=args}
  assert_status "$args, sin sesión" 1 $ST "$OUT"
  assert_contains "$args: lo explica" "solo se puede alargar una sesión por tiempo" "$OUT"
done
run_guardian start
run_guardian extend
assert_status "con una sesión sin fin" 1 $ST "$OUT"
assert_eq "que sigue sin fin" indefinite "$(state_value SESSION)"

section "Una sesión sin fin convertida: la duración se cuenta desde la conversión (S2)"
new_case
run_guardian start
at_minute 60
run_guardian start 25
assert_eq "TIMED_STARTED es la hora de la conversión" $(( T0 + 60 * 60 )) "$(state_value TIMED_STARTED)"
assert_eq "SESSION_STARTED se conserva" $T0 "$(state_value SESSION_STARTED)"
run_guardian extend 50
assert_eq "fin a los 110 min (60 + 50)" $(( T0 + 110 * 60 )) "$(state_value SESSION_ENDS)"

finish
