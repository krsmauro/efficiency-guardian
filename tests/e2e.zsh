# Ayudas para las pruebas de punta a punta (tests/test-commands.zsh y test-errors.zsh):
# cada caso tiene su propia carpeta con una copia del hosts de prueba, y el motor
# del repositorio se ejecuta sobre ella sin root, usando las variables GUARDIAN_*.

typeset -gi CASE_NUMBER=0

# new_case [carpeta de listas]   (por defecto, las listas reales del repositorio)
# Deja en CASE la carpeta del caso, con:
#   hosts      el archivo que modifica el motor
#   original   una copia intacta, para comparar
#   data/      donde el motor guarda la copia de seguridad (no existe hasta el primer cambio)
new_case() {
  CASE_NUMBER=$(( CASE_NUMBER + 1 ))
  CASE=$T_TMP/case$CASE_NUMBER
  CASE_LISTS=${1:-$REPO/blocklists}
  mkdir -p $CASE
  cp $REPO/tests/fixtures/hosts $CASE/hosts
  cp $CASE/hosts $CASE/original
}

# run_guardian subcomando...  → deja la salida (stdout y stderr) en OUT y el código en ST.
run_guardian() {
  OUT=$(GUARDIAN_LIB_DIR=$REPO/lib GUARDIAN_HOSTS_FILE=$CASE/hosts \
        GUARDIAN_BLOCKLIST_DIR=$CASE_LISTS GUARDIAN_DATA_DIR=$CASE/data \
        $REPO/bin/guardian "$@" 2>&1)
  ST=$?
}

# Archivos temporales que el motor haya dejado olvidados junto al hosts.
leftover_temps() {
  print -r -- $CASE/.hosts.guardian.*(N)
}

# El bloque que debería escribir start con las listas reales, calculado sin usar el motor.
expected_block() {
  print -r -- '# >>> efficiency-guardian (gestionado automáticamente; no editar a mano) >>>'
  awk '{ sub(/#.*/, ""); gsub(/[ \t\r]/, "") } NF && !seen[tolower($0)]++ { d = tolower($0); print "0.0.0.0 " d; print ":: " d }' \
    $REPO/blocklists/*.txt
  print -r -- '# <<< efficiency-guardian <<<'
}
