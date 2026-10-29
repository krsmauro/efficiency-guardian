#!/bin/zsh -f
# Pruebas de punta a punta de los errores (casos 5-7 de la Fase 1 y uso incorrecto).
# En todos, el motor debe salir con error y dejar el hosts intacto.

source ${0:A:h}/assert.zsh
source ${0:A:h}/e2e.zsh

# assert_untouched "descripción" inodo_de_antes
assert_untouched() {
  assert_same_file "$1: hosts intacto" $CASE/original $CASE/hosts
  assert_eq "$1: no se reescribió" "$2" "$(inode_of $CASE/hosts)"
  assert_eq "$1: sin temporales olvidados" "" "$(leftover_temps)"
}

section "Marcador de inicio sin fin (caso 5)"
new_case
print -r -- '# >>> efficiency-guardian (gestionado automáticamente; no editar a mano) >>>' >> $CASE/hosts
cp $CASE/hosts $CASE/original
inode=$(inode_of $CASE/hosts)
for command in start stop status; do
  run_guardian $command
  assert_status "$command sale con error" 1 $ST "$OUT"
  assert_contains "$command explica el problema" "marcadores" "$OUT"
  assert_untouched $command $inode
done

section "Dominio inválido o prohibido en una lista (casos 6 y 7)"
for bad in 'you tube.com' '*.youtube.com' 'accounts.youtube.com'; do
  mkdir -p $T_TMP/lists-bad
  print -rl -- youtube.com "$bad" > $T_TMP/lists-bad/youtube.txt
  new_case $T_TMP/lists-bad
  inode=$(inode_of $CASE/hosts)
  run_guardian start
  assert_status "start con ${(qq)bad} sale con error" 1 $ST "$OUT"
  assert_contains "dice dónde está" "youtube.txt:2" "$OUT"
  assert_untouched "${(qq)bad}" $inode
done

section "stop no depende de las listas"
new_case
run_guardian start
CASE_LISTS=$T_TMP/lists-bad
run_guardian stop
assert_status "con listas dañadas, stop igual desbloquea" 0 $ST "$OUT"
assert_same_file "y deja el original" $CASE/original $CASE/hosts

section "Uso incorrecto"
new_case
inode=$(inode_of $CASE/hosts)
for args in '' 'rm' 'start 25' 'status --json' 'START'; do
  run_guardian ${=args}
  assert_status "${(qq)args} es rechazado" 2 $ST "$OUT"
  assert_contains "${(qq)args} muestra el uso" "Uso: guardian" "$OUT"
done
assert_untouched "uso incorrecto" $inode

section "Sin root ni archivo de prueba"
OUT=$(GUARDIAN_LIB_DIR=$REPO/lib $REPO/bin/guardian start 2>&1)
assert_status "start pide sudo en vez de intentarlo" 1 $? "$OUT"
assert_contains "lo explica" "necesita root" "$OUT"

section "Archivos que faltan"
new_case
rm $CASE/hosts
run_guardian status
assert_status "sin hosts: error" 1 $ST "$OUT"
OUT=$(GUARDIAN_LIB_DIR=$T_TMP/no-existe $REPO/bin/guardian status 2>&1)
assert_status "sin módulos: error" 1 $? "$OUT"
assert_contains "dice qué módulo falta" "no-existe/env.zsh" "$OUT"

finish
