# Subcomando start: escribe el bloque con todos los grupos de las listas, o lo
# actualiza si las listas cambiaron. Si ya está igual, no toca el archivo.
#
# Alcance de la Fase 1: el bloqueo no tiene fin. La Fase 4 añade sesiones por
# tiempo, el retraso al terminar y los pases.

cmd_start() {
  local current count

  require_write_access
  blocklist_load $BLOCKLIST_DIR || die "no se activó nada: corrige las listas de $BLOCKLIST_DIR"
  count=$#BLOCKED_DOMAINS

  hosts_read $HOSTS_FILE
  current=$REPLY
  hosts_parse "$current" || die "$HOSTS_ERROR"
  hosts_with_block "$HOSTS_OUTSIDE" "${BLOCKED_DOMAINS[@]}"

  if [[ $REPLY == "$current" ]]; then
    say "Ya estaba activo: $count dominios bloqueados."
    return 0
  fi

  hosts_backup_once "$current"
  hosts_write_atomic $HOSTS_FILE "$REPLY"
  dns_flush
  log_event "start: $count dominios"
  say "Activo: $count dominios bloqueados."
}
