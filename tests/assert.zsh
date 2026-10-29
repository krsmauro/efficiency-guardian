# Funciones compartidas por las pruebas. Cada tests/test-*.zsh empieza con:
#   source ${0:A:h}/assert.zsh
# Ninguna prueba necesita root: todas trabajan en una carpeta temporal ($T_TMP)
# que se borra al terminar.

emulate -R zsh
setopt NO_UNSET PIPE_FAIL
export LC_ALL=C PATH=/usr/bin:/bin:/usr/sbin:/sbin

# Que ninguna variable del entorno se cuele en las pruebas.
unset GUARDIAN_HOSTS_FILE GUARDIAN_BLOCKLIST_DIR GUARDIAN_DATA_DIR GUARDIAN_LIB_DIR GUARDIAN_CONFIG \
      GUARDIAN_NOW GUARDIAN_BOOT_ID GUARDIAN_OSASCRIPT GUARDIAN_LSAPPINFO

readonly REPO=${${(%):-%x}:A:h:h}     # carpeta del repositorio (dos niveles arriba de este archivo)
readonly T_TMP=$(mktemp -d "${TMPDIR:-/tmp}/guardian-test.XXXXXX")
trap 'rm -rf -- "$T_TMP"' EXIT
typeset -gi T_PASS=0 T_FAIL=0

ok() {
  T_PASS=$(( T_PASS + 1 ))
  print -r -- "  ok     $1"
}

# fail "descripción" [detalle...]
fail() {
  T_FAIL=$(( T_FAIL + 1 ))
  print -r -- "  FALLA  $1"
  shift
  local line
  for line in "$@"; do print -r -- "         $line"; done
}

# Título de un grupo de casos.
section() {
  print -r -- "- $1"
}

# assert_eq "descripción" esperado obtenido
assert_eq() {
  if [[ $2 == "$3" ]]; then ok "$1"; else fail "$1" "esperado: ${(qqqq)2}" "obtenido: ${(qqqq)3}"; fi
}

# assert_contains "descripción" "texto buscado" "texto donde buscar"
assert_contains() {
  if [[ $3 == *"$2"* ]]; then ok "$1"; else fail "$1" "no aparece: ${(qqqq)2}" "en: ${(qqqq)3}"; fi
}

# assert_status "descripción" código_esperado código_obtenido "salida del comando"
assert_status() {
  if [[ $2 == "$3" ]]; then ok "$1"; else fail "$1" "código esperado $2, obtenido $3" "salida: ${(qqqq)4}"; fi
}

# assert_true "descripción" comando...    (pasa si el comando sale con 0)
assert_true() {
  local description=$1
  shift
  if "$@"; then ok "$description"; else fail "$description" "falló: $*"; fi
}

# assert_false "descripción" comando...   (pasa si el comando sale con algo distinto de 0)
assert_false() {
  local description=$1
  shift
  if "$@"; then fail "$description" "no falló: $*"; else ok "$description"; fi
}

# assert_same_file "descripción" archivo_esperado archivo_obtenido
assert_same_file() {
  if cmp -s -- "$2" "$3"; then
    ok "$1"
  else
    fail "$1" "${(@f)$(diff -- "$2" "$3" | head -n 12)}"
  fi
}

# Número de inodo: si cambia, el archivo se reescribió (la escritura atómica crea uno nuevo).
inode_of() {
  stat -f %i -- "$1"
}

# Permisos en octal, por ejemplo 644.
mode_of() {
  stat -f %Lp -- "$1"
}

# Termina el archivo de pruebas con un resumen. Sale con 1 si algo falló.
finish() {
  print -r -- "  $T_PASS ok, $T_FAIL fallas"
  exit $(( T_FAIL > 0 ))
}
