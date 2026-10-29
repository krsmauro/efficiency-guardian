#!/bin/zsh -f
# Pruebas de tests/check-length.zsh (regla de tamaño D13, caso 12 de la Fase 1).
# Crea un repositorio de mentira en una carpeta temporal y comprueba los umbrales.

source ${0:A:h}/assert.zsh

fake=$T_TMP/repo
mkdir -p $fake/{bin,lib,close-tabs,tools,install,tests/fixtures/sub,blocklists}

# make_file ruta número_de_líneas
make_file() {
  print -l {1..$2} > $fake/$1
}

# check: ejecuta la regla sobre el repositorio de mentira; deja la salida en OUT y el código en ST.
check() {
  OUT=$(/bin/zsh -f $REPO/tests/check-length.zsh $fake 2>&1)
  ST=$?
}

section "Umbrales"
make_file lib/a.zsh 100
check
assert_status "100 líneas: pasa" 0 $ST "$OUT"
assert_eq "100 líneas: sin avisos" "" "${(M)OUT:#*AVISO*}"

make_file lib/a.zsh 101
check
assert_status "101 líneas: pasa" 0 $ST "$OUT"
assert_contains "101 líneas: avisa" "AVISO  lib/a.zsh: 101" "$OUT"

make_file lib/a.zsh 149
check
assert_status "149 líneas: todavía pasa" 0 $ST "$OUT"

make_file lib/a.zsh 150
check
assert_status "150 líneas: falla" 1 $ST "$OUT"
assert_contains "150 líneas: lo explica" "ERROR  lib/a.zsh: 150" "$OUT"
make_file lib/a.zsh 10

section "Qué cuenta como código"
for code_file in bin/guardian install.sh install/x.zsh uninstall.sh tests/test-x.zsh \
                 close-tabs/x.js close-tabs/x.zsh tools/x.zsh; do
  make_file $code_file 150
  check
  assert_status "$code_file cuenta como código" 1 $ST "$OUT"
  rm $fake/$code_file
done

for data_file in blocklists/youtube.txt tests/fixtures/hosts tests/fixtures/sub/big lib/notas.md; do
  make_file $data_file 500
  check
  assert_status "$data_file no cuenta (datos o documentación)" 0 $ST "$OUT"
  rm $fake/$data_file
done

section "El repositorio real cumple la regla"
OUT=$(/bin/zsh -f $REPO/tests/check-length.zsh 2>&1)
assert_status "ningún archivo llega a 150 líneas" 0 $? "$OUT"

finish
