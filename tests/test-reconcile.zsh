#!/bin/zsh -f
# Pruebas de punta a punta de reconcile: arranques (BOOT_ID), arranque
# automático, la primera vez sin estado y hosts editado a mano.
# (El fin de las sesiones por tiempo, del retraso y del pase se prueba en
# test-sessions.zsh, test-stop.zsh y test-pass.zsh.)

source ${0:A:h}/assert.zsh
source ${0:A:h}/e2e.zsh

section "Arranque nuevo: termina la sin fin y el arranque automático crea otra"
new_case
run_guardian start
run_guardian pass
reboot
at_minute 600
run_guardian reconcile
assert_status "sale con 0" 0 $ST "$OUT"
assert_eq "sesión sin fin" indefinite "$(state_value SESSION)"
assert_eq "nueva: empieza ahora" $(( T0 + 600 * 60 )) "$(state_value SESSION_STARTED)"
assert_eq "contador a 0" 0 "$(state_value PASSES_USED)"
assert_eq "guarda el arranque nuevo" boot2 "$(state_value BOOT_ID)"
assert_true "bloquea" blocked youtube.com

section "Sin arranque automático: reiniciar termina la sin fin"
new_case
set_config AUTOSTART_AT_BOOT no
run_guardian start
reboot
run_guardian reconcile
assert_eq "sin sesión" none "$(state_value SESSION)"
assert_same_file "hosts vuelve al original" $CASE/original $CASE/hosts

section "La sesión por tiempo sobrevive a un reinicio si no venció"
new_case
run_guardian start 50
reboot
at_minute 20
run_guardian reconcile
assert_eq "sigue" timed "$(state_value SESSION)"
assert_eq "con la misma hora de fin" $(( T0 + 50 * 60 )) "$(state_value SESSION_ENDS)"

section "Si venció con el Mac apagado, termina y arranca la automática"
new_case
run_guardian start 25
reboot
at_minute 600
run_guardian reconcile
assert_eq "sesión sin fin nueva" "indefinite $(( T0 + 600 * 60 ))" \
  "$(state_value SESSION) $(state_value SESSION_STARTED)"

section "Primera vez, sin bloque: instalar no activa el bloqueo"
new_case
inode=$(inode_of $CASE/hosts)
run_guardian reconcile
assert_status "sale con 0" 0 $ST "$OUT"
assert_eq "sin sesión, aunque el arranque automático está activo" none "$(state_value SESSION)"
assert_eq "hosts intacto" "$inode" "$(inode_of $CASE/hosts)"
reboot
run_guardian reconcile
assert_eq "en el siguiente arranque, sí empieza la sesión" indefinite "$(state_value SESSION)"

section "Primera vez, con un bloque de la Fase 1: se conserva"
new_case
run_guardian start
rm $CASE/data/state
inode=$(inode_of $CASE/hosts)
run_guardian reconcile
assert_eq "sesión sin fin" indefinite "$(state_value SESSION)"
assert_eq "hosts intacto" "$inode" "$(inode_of $CASE/hosts)"

section "Estado dañado: se conserva el bloque"
print -r -- "SESSION=rota" > $CASE/data/state
run_guardian reconcile
assert_contains "avisa" "estado dañado" "$OUT"
assert_eq "sesión sin fin" indefinite "$(state_value SESSION)"
assert_true "sigue bloqueado" blocked youtube.com

section "hosts editado a mano durante una sesión: reconcile lo restaura"
cp $CASE/hosts $CASE/blocked
cp $CASE/original $CASE/hosts
run_guardian reconcile
assert_same_file "el bloque vuelve" $CASE/blocked $CASE/hosts

section "Sin cambios, reconcile no escribe nada"
hosts_inode=$(inode_of $CASE/hosts) state_inode=$(inode_of $CASE/data/state)
at_minute 1
run_guardian reconcile
assert_eq "no dice nada" "" "$OUT"
assert_eq "hosts: mismo inodo" "$hosts_inode" "$(inode_of $CASE/hosts)"
assert_eq "estado: mismo inodo" "$state_inode" "$(inode_of $CASE/data/state)"

finish
