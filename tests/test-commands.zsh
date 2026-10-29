#!/bin/zsh -f
# Pruebas de punta a punta de start, stop y status (casos 1-4, 9 y 10 de la Fase 1),
# con el motor real del repositorio sobre una copia temporal del hosts.
# Con STOP_DELAY_MINUTES=0, stop desbloquea en el acto, como en la Fase 1. El
# retraso al terminar se prueba en test-stop.zsh.

source ${0:A:h}/assert.zsh
source ${0:A:h}/e2e.zsh

total=$(( $(expected_block | wc -l) / 2 - 1 ))    # dominios: 2 líneas cada uno, menos los marcadores

# Un caso nuevo con stop inmediato.
new_case_now() {
  new_case "$@"
  set_config STOP_DELAY_MINUTES 0
}

section "status sin bloque (caso 10)"
new_case_now
run_guardian status
assert_status "sale con 0" 0 $ST "$OUT"
assert_eq "dice que no hay sesión ni bloqueo" $'Sesión: ninguna\nBloqueo: inactivo' "$OUT"

section "start (caso 1)"
run_guardian start
assert_status "sale con 0" 0 $ST "$OUT"
assert_contains "lo dice" "Sesión sin fin iniciada. $total dominios bloqueados." "$OUT"
size=$(stat -f %z $CASE/original)
head -c $size $CASE/hosts > $CASE/head
assert_same_file "el contenido original queda intacto, byte a byte" $CASE/original $CASE/head
{ print; expected_block } > $CASE/expected-tail
tail -c +$(( size + 1 )) $CASE/hosts > $CASE/tail
assert_same_file "al final: línea en blanco y el bloque, 2 líneas por dominio" $CASE/expected-tail $CASE/tail
assert_eq "permisos 644" 644 "$(mode_of $CASE/hosts)"
assert_eq "sin temporales olvidados" "" "$(leftover_temps)"

section "Copia de seguridad del original"
assert_same_file "data/hosts.original es el hosts de antes" $CASE/original $CASE/data/hosts.original
assert_eq "la copia es privada (600)" 600 "$(mode_of $CASE/data/hosts.original)"
assert_eq "su carpeta es 755: la app lee el estado sin root" 755 "$(mode_of $CASE/data)"

section "status con bloque (caso 10)"
run_guardian status
assert_contains "dice activo y cuántos" "Bloqueo: activo ($total dominios)" "$OUT"

section "start otra vez (caso 2)"
written=$(inode_of $CASE/hosts)
cp $CASE/hosts $CASE/after-first-start
run_guardian start
assert_status "sale con 0" 0 $ST "$OUT"
assert_contains "dice que ya había una sesión" "Ya había una sesión" "$OUT"
assert_same_file "el archivo no cambia" $CASE/after-first-start $CASE/hosts
assert_eq "no lo reescribe (mismo inodo)" "$written" "$(inode_of $CASE/hosts)"

section "stop (caso 3)"
run_guardian stop
assert_status "sale con 0" 0 $ST "$OUT"
assert_contains "lo dice" "Sesión terminada" "$OUT"
assert_same_file "el hosts queda idéntico al original" $CASE/original $CASE/hosts
run_guardian status
assert_contains "status dice inactivo" "Bloqueo: inactivo" "$OUT"

section "La copia de seguridad no se sobrescribe"
print -r -- "10.0.0.1 nas.local" >> $CASE/hosts
run_guardian start
assert_same_file "sigue siendo el hosts de la primera vez" $CASE/original $CASE/data/hosts.original
run_guardian stop

section "stop sin bloque (caso 4)"
new_case_now
before=$(inode_of $CASE/hosts)
run_guardian stop
assert_status "sale con 0" 0 $ST "$OUT"
assert_contains "dice que no había sesión" "No había sesión" "$OUT"
assert_eq "no toca el archivo (mismo inodo)" "$before" "$(inode_of $CASE/hosts)"
assert_eq "no crea copia de seguridad" "" "$(print -r -- $CASE/data/hosts.original(N))"

section "hosts sin salto de línea final (caso 9)"
new_case_now
print -rn -- "$(cat $CASE/original)" > $CASE/hosts     # $(...) quita el salto de línea final
run_guardian start
assert_status "start sale con 0" 0 $ST "$OUT"
assert_eq "la última línea original no se pega al bloque" "0.0.0.0 youtu.be" "$(sed -n "$(wc -l < $CASE/original)p" $CASE/hosts)"
run_guardian stop
assert_same_file "stop lo deja como el original, con su salto de línea" $CASE/original $CASE/hosts

finish
