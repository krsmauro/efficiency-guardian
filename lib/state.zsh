# Estado de la sesión: leerlo, validarlo y escribirlo de forma atómica.
#
# Archivo: DATA_DIR/state (root:wheel 644; la app de la Fase 5 lo lee sin root).
#   SESSION=none|indefinite|timed
#   SESSION_STARTED=<epoch>      cuándo empezó la sesión (0 sin sesión)
#   SESSION_ENDS=<epoch o 0>     fin de una sesión por tiempo
#   TIMED_STARTED=<epoch o 0>    cuándo empezó la parte por tiempo (acortar se mide desde ahí)
#   BOOT_ID=<uuid>               arranque en el que se escribió (ver clock.zsh)
#   STOP_AT=<epoch o 0>          terminación pendiente (retraso al terminar)
#   PASSES_USED=<n>              pases usados en esta sesión
#   PASS_UNTIL=<epoch o 0>       fin del pase en curso
#   PASS_GROUP=<grupo o nada>    el grupo que desbloquea el pase en curso
# En memoria, cada clave es un elemento del array asociativo S.
# Se lee línea por línea, sin "source": nunca se ejecuta como código.

readonly STATE_KEYS=(
  SESSION SESSION_STARTED SESSION_ENDS TIMED_STARTED BOOT_ID STOP_AT PASSES_USED PASS_UNTIL PASS_GROUP
)

# state_load
# Deja el estado en S, y en STATE_EXISTS 1 si el archivo existía y era válido.
# Si no existe (primera vez) o está dañado, S queda "sin sesión" y STATE_EXISTS
# en 0: session_init (session.zsh) decide cómo empezar.
state_load() {
  local file=$DATA_DIR/state line key value
  state_reset
  typeset -g STATE_EXISTS=0 STATE_TEXT=

  if [[ ! -e $file ]]; then return 0; fi
  STATE_TEXT=$(cat -- $file; print -n x) || die "no se puede leer $file"
  STATE_TEXT=${STATE_TEXT%x}
  # =~ se detiene en un byte nulo: un valor "0<NUL>x" pasaría la validación.
  if [[ $STATE_TEXT == *$'\0'* ]]; then state_damaged "tiene un byte nulo"; return 0; fi

  for line in "${(@f)STATE_TEXT}"; do
    if [[ -z $line ]]; then continue; fi
    key=${line%%=*} value=${line#*=}
    # (Sin =~ aquí: state_valid usa otro =~, que pisaría $match.)
    if [[ $line != *=* ]] || ! state_valid $key "$value"; then
      state_damaged "línea inválida: ${(qq)line}"
      return 0
    fi
    S[$key]=$value
  done
  STATE_EXISTS=1
}

# state_valid clave valor → 0 si la clave existe y el valor tiene la forma correcta.
state_valid() {
  case $1 in
    SESSION) [[ $2 == (none|indefinite|timed) ]] ;;
    BOOT_ID) [[ $2 =~ $BOOT_ID_REGEX ]] ;;
    SESSION_STARTED|SESSION_ENDS|TIMED_STARTED|STOP_AT|PASSES_USED|PASS_UNTIL) [[ $2 =~ '^(0|[1-9][0-9]{0,11})$' ]] ;;
    PASS_GROUP) [[ -z $2 || $2 =~ '^[a-z0-9-]+$' ]] ;;   # como GROUP_REGEX (blocklist.zsh)
    *) return 1 ;;
  esac
}

# Un estado dañado no detiene el motor: se avisa, se registra y se empieza de
# nuevo como si no existiera (session_init conserva el bloqueo que haya en hosts).
state_damaged() {
  warn "estado dañado en $DATA_DIR/state ($1): se empieza de nuevo"   # warn también lo registra
  state_reset
}

# S "sin sesión". Las claves que falten en el archivo se quedan con estos valores.
state_reset() {
  typeset -gA S=(SESSION none SESSION_STARTED 0 SESSION_ENDS 0 TIMED_STARTED 0 BOOT_ID ''
                 STOP_AT 0 PASSES_USED 0 PASS_UNTIL 0 PASS_GROUP '')
}

# Deja en REPLY el texto del archivo, con las claves siempre en el mismo orden.
state_serialize() {
  local key
  REPLY=
  for key in $STATE_KEYS; do REPLY+="$key=$S[$key]"$'\n'; done
}

# state_save
# Escribe S solo si cambió (así reconcile, cada 30 s, no reescribe el archivo
# sin motivo). Temporal en la misma carpeta + mv: nunca queda a medio escribir.
state_save() {
  local file=$DATA_DIR/state tmp
  state_serialize
  if (( STATE_EXISTS )) && [[ $REPLY == "$STATE_TEXT" ]]; then return 0; fi
  data_dir_ensure
  tmp=$(mktemp "$DATA_DIR/.state.XXXXXX")
  if ! { print -rn -- "$REPLY" > $tmp && chmod 644 $tmp && set_root_owner $tmp && mv -f -- $tmp $file }; then
    rm -f -- $tmp
    die "no se pudo guardar el estado en $file"
  fi
  STATE_TEXT=$REPLY STATE_EXISTS=1
}
