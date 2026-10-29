# Rutas del motor y modo de ejecución (root o pruebas).
#
# Siendo root, todo apunta a las rutas reales y las variables GUARDIAN_* se
# ignoran: así nadie puede redirigir el motor hacia otros archivos. (sudo ya
# limpia esas variables; esto es una segunda barrera.)
#
# Sin root (pruebas), estas variables cambian las rutas:
#   GUARDIAN_HOSTS_FILE      el archivo hosts a modificar
#   GUARDIAN_BLOCKLIST_DIR   la carpeta de listas
#   GUARDIAN_DATA_DIR        dónde guardar el estado y la copia de seguridad
#   GUARDIAN_CONFIG          el archivo de configuración
# (El reloj y el arranque falsos están en clock.zsh.)
# Sin root no se puede tocar el /etc/hosts real, así que tampoco se vacía la
# caché DNS, ni se cambia el dueño de archivos, ni se escribe en el registro.

export LC_ALL=C   # comparaciones byte a byte y expresiones regulares predecibles

readonly REAL_HOSTS_FILE=/etc/hosts
readonly REAL_BLOCKLIST_DIR=/usr/local/etc/efficiency-guardian/blocklists
readonly REAL_CONFIG_FILE=/usr/local/etc/efficiency-guardian/config
readonly REAL_DATA_DIR=/var/db/efficiency-guardian

if (( EUID == 0 )); then
  IS_ROOT=1
  HOSTS_FILE=$REAL_HOSTS_FILE
  BLOCKLIST_DIR=$REAL_BLOCKLIST_DIR
  CONFIG_FILE=$REAL_CONFIG_FILE
  DATA_DIR=$REAL_DATA_DIR
else
  IS_ROOT=0
  HOSTS_FILE=${GUARDIAN_HOSTS_FILE:-$REAL_HOSTS_FILE}
  BLOCKLIST_DIR=${GUARDIAN_BLOCKLIST_DIR:-$REAL_BLOCKLIST_DIR}
  CONFIG_FILE=${GUARDIAN_CONFIG:-$REAL_CONFIG_FILE}
  DATA_DIR=${GUARDIAN_DATA_DIR:-$REAL_DATA_DIR}
fi

# Los subcomandos que escriben exigen root, salvo en pruebas (con GUARDIAN_HOSTS_FILE).
require_write_access() {
  if (( IS_ROOT )) || [[ -n ${GUARDIAN_HOSTS_FILE:-} ]]; then
    return 0
  fi
  die "este comando necesita root: usa sudo"
}

# Crea la carpeta de datos si falta. 755: la app (sin root) lee el estado; las
# copias de seguridad que hay dentro son 600.
data_dir_ensure() {
  if [[ ! -d $DATA_DIR ]]; then mkdir -m 755 -- $DATA_DIR; fi
}
