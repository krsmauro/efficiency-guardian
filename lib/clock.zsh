# La hora actual y el identificador del arranque actual del Mac (BOOT_ID).
#
# NOW se fija una sola vez al empezar: todo el comando usa la misma hora.
# BOOT_ID sale de kern.bootsessionuuid, que cambia en cada arranque: si no
# coincide con el guardado en el estado, el Mac se apagó o se reinició.
#
# Sin root (pruebas), dos variables los fingen:
#   GUARDIAN_NOW      segundos desde 1970 (epoch)
#   GUARDIAN_BOOT_ID  cualquier texto; cambiarlo simula un reinicio
# Siendo root se ignoran: siempre el reloj y el arranque reales.

zmodload zsh/datetime   # EPOCHSECONDS y strftime, sin procesos externos

readonly BOOT_ID_REGEX='^[A-Za-z0-9-]{1,64}$'

clock_init() {
  if (( ! IS_ROOT )) && [[ -n ${GUARDIAN_NOW:-} ]]; then
    if [[ ! $GUARDIAN_NOW =~ '^[0-9]{1,12}$' ]]; then die "GUARDIAN_NOW debe ser un número"; fi
    NOW=$GUARDIAN_NOW
  else
    NOW=$EPOCHSECONDS
  fi

  if (( ! IS_ROOT )) && [[ -n ${GUARDIAN_BOOT_ID:-} ]]; then
    BOOT_ID=$GUARDIAN_BOOT_ID
  else
    BOOT_ID=$(sysctl -n kern.bootsessionuuid) || die "no se pudo leer kern.bootsessionuuid"
  fi
  if [[ ! $BOOT_ID =~ $BOOT_ID_REGEX ]]; then die "identificador de arranque inesperado: ${(qq)BOOT_ID}"; fi
}

# hhmm epoch → deja en REPLY la hora local, por ejemplo "14:05".
hhmm() {
  strftime -s REPLY %H:%M $1
}
