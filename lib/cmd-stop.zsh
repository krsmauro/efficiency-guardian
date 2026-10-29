# Subcomando stop: quita el bloque gestionado. Si no existe, no hace nada.
# No lee las listas: aunque estén dañadas, stop siempre puede desbloquear.
#
# Alcance de la Fase 1: desbloquea de inmediato. La Fase 4 añade el retraso
# al terminar (STOP_DELAY_MINUTES) y el candado.

cmd_stop() {
  require_write_access

  hosts_read $HOSTS_FILE
  hosts_parse "$REPLY" || die "$HOSTS_ERROR"

  if (( ! HOSTS_ACTIVE )); then
    say "Ya estaba inactivo."
    return 0
  fi

  hosts_write_atomic $HOSTS_FILE "$HOSTS_OUTSIDE"
  dns_flush
  log_event "stop"
  say "Inactivo: se quitó el bloqueo."
}
