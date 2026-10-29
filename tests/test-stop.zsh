#!/bin/zsh -f
# Pruebas de punta a punta de stop y cancel-stop: el retraso al terminar (D10,
# confirmado para todas las sesiones: S1) y el candado (TIMED_LOCK).

source ${0:A:h}/assert.zsh
source ${0:A:h}/e2e.zsh

section "stop deja la terminación pendiente"
new_case
run_guardian start
at_minute 10
run_guardian stop
assert_status "sale con 0" 0 $ST "$OUT"
assert_contains "dice hasta cuándo sigue" "El bloqueo sigue hasta las 08:15" "$OUT"
# Fallo de 4.4: decía "guardian cancel-stop", que no está en el PATH y necesita sudo.
assert_contains "y el comando completo para anularla" \
  "Para seguir trabajando: sudo /usr/local/sbin/guardian cancel-stop" "$OUT"
assert_eq "terminación en 5 min" $(( T0 + 15 * 60 )) "$(state_value STOP_AT)"
assert_true "el bloqueo sigue" blocked youtube.com

section "Pedirlo otra vez no alarga ni acorta la espera"
at_minute 12
run_guardian stop
assert_contains "lo dice" "Ya había una terminación pendiente: el bloqueo termina a las 08:15" "$OUT"
assert_eq "misma hora" $(( T0 + 15 * 60 )) "$(state_value STOP_AT)"

section "reconcile termina la sesión al cumplirse el retraso"
at_minute 14
run_guardian reconcile
assert_eq "a los 4 min, sigue" indefinite "$(state_value SESSION)"
at_minute 15
run_guardian reconcile
assert_eq "a los 5, termina" none "$(state_value SESSION)"
assert_same_file "hosts vuelve al original" $CASE/original $CASE/hosts

section "cancel-stop la anula"
new_case
run_guardian start
run_guardian stop
run_guardian cancel-stop
assert_status "sale con 0" 0 $ST "$OUT"
assert_contains "lo dice" "Terminación cancelada" "$OUT"
assert_eq "sin terminación pendiente" 0 "$(state_value STOP_AT)"
at_minute 30
run_guardian reconcile
assert_eq "a los 30 min sigue la sesión" indefinite "$(state_value SESSION)"
run_guardian cancel-stop
assert_contains "sin nada que cancelar, lo dice" "No había ninguna terminación pendiente" "$OUT"

section "start durante la espera también la anula"
new_case
run_guardian start
run_guardian stop
run_guardian start
assert_contains "lo dice" "Terminación cancelada" "$OUT"
assert_eq "sin terminación pendiente" 0 "$(state_value STOP_AT)"

section "Una sesión por tiempo que acaba antes que el retraso"
new_case
run_guardian start 25
at_minute 23
run_guardian stop
assert_contains "dice la hora real de fin" "El bloqueo sigue hasta las 08:25" "$OUT"

section "stop sin sesión"
new_case
run_guardian stop
assert_status "sale con 0" 0 $ST "$OUT"
assert_contains "lo dice" "No había sesión" "$OUT"

section "TIMED_LOCK=yes: no se puede terminar antes de la hora"
new_case
set_config TIMED_LOCK yes
run_guardian start 25
run_guardian stop
assert_status "stop es rechazado" 1 $ST "$OUT"
assert_contains "dice cuándo termina" "sesión con candado: termina a las 08:25" "$OUT"
assert_eq "sin terminación pendiente" 0 "$(state_value STOP_AT)"
run_guardian pass
assert_status "pero el pase funciona" 0 $ST "$OUT"
at_minute 25
run_guardian reconcile
assert_eq "a la hora, termina" none "$(state_value SESSION)"

section "El candado no aplica a la sesión sin fin"
run_guardian start
run_guardian stop
assert_status "stop funciona" 0 $ST "$OUT"
assert_false "y deja la terminación pendiente" test "$(state_value STOP_AT)" = 0

finish
