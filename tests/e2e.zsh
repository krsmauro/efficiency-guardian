# Ayudas para las pruebas de punta a punta (test-commands.zsh, test-sessions.zsh...).
# Cada caso tiene su propia carpeta con una copia del hosts de prueba y de
# config.default, y el motor del repositorio se ejecuta sobre ella sin root,
# usando las variables GUARDIAN_*. El reloj y el arranque son falsos.

typeset -gi CASE_NUMBER=0
readonly T0=1800000000     # hora de partida de cada caso: 08:00 en UTC

# new_case [carpeta de listas]   (por defecto, las listas reales del repositorio)
# Deja en CASE la carpeta del caso, con:
#   hosts      el archivo que modifica el motor
#   original   una copia intacta, para comparar
#   config     una copia de config.default (se cambia con set_config)
#   data/      estado, candado y copia de seguridad (no existe hasta que el motor escribe)
# El reloj empieza en T0 (at_minute lo mueve) y el arranque es "boot1" (reboot lo cambia).
new_case() {
  CASE_NUMBER=$(( CASE_NUMBER + 1 ))
  CASE=$T_TMP/case$CASE_NUMBER
  CASE_LISTS=${1:-$REPO/blocklists}
  CASE_NOW=$T0 CASE_BOOT=1
  mkdir -p $CASE
  cp $REPO/tests/fixtures/hosts $CASE/hosts
  cp $CASE/hosts $CASE/original
  cp $REPO/config.default $CASE/config
}

# run_guardian subcomando...  → deja la salida (stdout y stderr) en OUT y el código en ST.
run_guardian() {
  OUT=$(GUARDIAN_LIB_DIR=$REPO/lib GUARDIAN_HOSTS_FILE=$CASE/hosts \
        GUARDIAN_BLOCKLIST_DIR=$CASE_LISTS GUARDIAN_DATA_DIR=$CASE/data \
        GUARDIAN_CONFIG=$CASE/config GUARDIAN_NOW=$CASE_NOW GUARDIAN_BOOT_ID=boot$CASE_BOOT \
        TZ=UTC $REPO/bin/guardian "$@" 2>&1)
  ST=$?
}

# set_config CLAVE valor   (reemplaza la línea de esa clave en la config del caso)
set_config() {
  grep -v "^$1=" $CASE/config > $CASE/config.new || true
  print -r -- "$1=$2" >> $CASE/config.new
  mv $CASE/config.new $CASE/config
}

# at_minute N   → el reloj falso pasa a T0 + N minutos
at_minute() {
  CASE_NOW=$(( T0 + $1 * 60 ))
}

# reboot   → simula que el Mac se apagó y volvió a arrancar (otro BOOT_ID)
reboot() {
  CASE_BOOT=$(( CASE_BOOT + 1 ))
}

# state_value CLAVE   → imprime ese valor del estado guardado
state_value() {
  sed -n "s/^$1=//p" $CASE/data/state
}

# blocked dominio   → 0 si el dominio está ahora DENTRO del bloque gestionado
# (el hosts de prueba tiene además 4 líneas manuales antiguas de YouTube, fuera).
blocked() {
  sed -n '/^# >>> efficiency-guardian/,/^# <<< efficiency-guardian/p' $CASE/hosts | grep -qx -- "0.0.0.0 $1"
}

# Archivos temporales que el motor haya dejado olvidados junto al hosts o al estado.
leftover_temps() {
  print -r -- $CASE/.hosts.guardian.*(N) $CASE/data/.state.*(N)
}

# El bloque que debería escribir start con las listas reales, calculado sin usar el motor.
expected_block() {
  print -r -- '# >>> efficiency-guardian (gestionado automáticamente; no editar a mano) >>>'
  awk '{ sub(/#.*/, ""); gsub(/[ \t\r]/, "") } NF && !seen[tolower($0)]++ { d = tolower($0); print "0.0.0.0 " d; print ":: " d }' \
    $REPO/blocklists/*.txt
  print -r -- '# <<< efficiency-guardian <<<'
}
