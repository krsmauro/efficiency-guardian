#!/bin/zsh -f
# Pruebas de punta a punta de pass: el pase temporal (D5).

source ${0:A:h}/assert.zsh
source ${0:A:h}/e2e.zsh

section "El pase quita solo PASS_GROUPS, y vuelven al vencer"
new_case
run_guardian start
run_guardian pass
assert_status "sale con 0" 0 $ST "$OUT"
assert_contains "dice hasta cuándo y cuántos quedan" "youtube desbloqueado hasta las 08:05. Te quedan 2 de 3." "$OUT"
assert_false "youtube.com desbloqueado" blocked youtube.com
assert_false "www.youtube.com desbloqueado" blocked www.youtube.com
assert_true "facebook.com sigue bloqueado" blocked facebook.com
assert_eq "cuenta el pase" 1 "$(state_value PASSES_USED)"
at_minute 4
run_guardian reconcile
assert_false "minuto 4: sigue desbloqueado" blocked youtube.com
at_minute 5
run_guardian reconcile
assert_contains "minuto 5: lo dice" "fin del pase" "$OUT"
assert_true "minuto 5: youtube.com bloqueado otra vez" blocked youtube.com
assert_eq "minuto 5: sin pase en curso" 0 "$(state_value PASS_UNTIL)"

section "Con un pase en curso, otro es rechazado"
at_minute 10
run_guardian pass
at_minute 12
run_guardian pass
assert_status "error" 1 $ST "$OUT"
assert_contains "dice hasta cuándo dura el actual" "ya hay un pase en curso, hasta las 08:15" "$OUT"
assert_eq "no lo cuenta" 2 "$(state_value PASSES_USED)"

section "El 4.º es rechazado"
at_minute 20
run_guardian pass
assert_status "el 3.º funciona" 0 $ST "$OUT"
assert_contains "y dice que no quedan" "Te quedan 0 de 3" "$OUT"
at_minute 30
run_guardian pass
assert_status "el 4.º no" 1 $ST "$OUT"
assert_contains "lo explica" "no quedan pases en esta sesión (3/3)" "$OUT"
# Un comando rechazado no escribe nada: el fin del 3.º lo aplica reconcile.
run_guardian reconcile
assert_eq "no hay pase en curso" 0 "$(state_value PASS_UNTIL)"
assert_true "youtube.com sigue bloqueado" blocked youtube.com

section "Sin sesión, rechazado"
new_case
run_guardian pass
assert_status "error" 1 $ST "$OUT"
assert_contains "lo explica" "no hay sesión" "$OUT"

section "Durante una terminación pendiente, sí se puede"
run_guardian start
run_guardian stop
run_guardian pass
assert_status "sale con 0" 0 $ST "$OUT"
at_minute 5
run_guardian reconcile
assert_eq "y la sesión termina a su hora" none "$(state_value SESSION)"
assert_same_file "hosts vuelve al original" $CASE/original $CASE/hosts

finish
