#!/bin/zsh -f
# Contrato entre el motor y la app (Fase 5): la salida de "status --json" debe
# coincidir byte a byte con los archivos de app/Tests/GuardianCoreTests/Fixtures/,
# que las pruebas de Swift decodifican (swift test --package-path app).
#
# Si cambias status-json.zsh, esta prueba falla a propósito. Entonces:
#   zsh tests/test-app-contract.zsh --write     (regenera los archivos)
# y adapta la app hasta que pase swift test.

source ${0:A:h}/assert.zsh
source ${0:A:h}/e2e.zsh

readonly FIXTURES=$REPO/app/Tests/GuardianCoreTests/Fixtures
WRITE=0
if [[ ${1:-} == --write ]]; then WRITE=1; fi

# Listas pequeñas y fijas: así el número de dominios no cambia al editar blocklists/.
readonly LISTS=$T_TMP/lists
mkdir -p $LISTS
print -l youtube.com www.youtube.com > $LISTS/youtube.txt
print -l facebook.com > $LISTS/facebook.txt

# check nombre   → compara (o, con --write, escribe) status --json con Fixtures/status-<nombre>.json
check() {
  local file=$FIXTURES/status-$1.json expected
  run_guardian status --json
  if (( ST != 0 )); then fail "$1: status --json falló" "$OUT"; return; fi
  if (( WRITE )); then
    print -r -- "$OUT" > $file
    ok "$1: escrito en ${file#$REPO/}"
  elif [[ ! -f $file ]]; then
    fail "$1: falta ${file#$REPO/}" "genéralo con: zsh tests/test-app-contract.zsh --write"
  else
    expected=$(<$file)
    assert_eq "$1: coincide con ${file#$REPO/}" "$expected" "$OUT"
  fi
}

section "Sin sesión"
new_case $LISTS
check none

section "Sesión sin fin"
new_case $LISTS
run_guardian start
at_minute 10
check indefinite

section "Sesión por tiempo con pase y terminación pendiente"
new_case $LISTS
run_guardian start 25
at_minute 1
run_guardian pass
at_minute 3
run_guardian stop
at_minute 4
check timed-pass-stop

section "Candado, sin fin convertida, pase del segundo grupo y sin arranque automático"
new_case $LISTS
set_config TIMED_LOCK yes
set_config PASS_GROUPS youtube,facebook
set_config AUTOSTART_AT_BOOT no
set_config TIMED_PRESETS 15,45
run_guardian start
at_minute 10
run_guardian start 45
at_minute 11
run_guardian pass facebook
check locked

finish
