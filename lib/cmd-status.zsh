# Subcomando status: dice si el bloqueo está activo. No necesita root.
#
# Salida (pensada para personas; la Fase 4 añade --json para la app):
#   activo (82 dominios)
#   inactivo
# Sale con 1 si los marcadores están dañados.

cmd_status() {
  hosts_read $HOSTS_FILE
  hosts_parse "$REPLY" || die "$HOSTS_ERROR"

  if (( HOSTS_ACTIVE )); then
    say "activo ($HOSTS_COUNT dominios)"
  else
    say "inactivo"
  fi
}
