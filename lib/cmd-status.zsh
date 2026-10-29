# Subcomando status [--json]: el estado de la sesión y del bloqueo. No necesita root.
#
# La sesión se muestra como la dejaría reconcile ahora mismo: si su tiempo ya
# pasó, dice que terminó aunque reconcile aún no haya reescrito hosts (tarda
# hasta 30 s). "Bloqueo", en cambio, es lo que hay en hosts en este instante.
# Sale con 1 si los marcadores de hosts están dañados.
#
#   Sesión: por tiempo, termina a las 10:30
#   Terminación pendiente: el bloqueo termina a las 10:05
#   Pase en curso: youtube, hasta las 10:02
#   Pases usados: 1 de 3
#   Bloqueo: activo (78 dominios)

cmd_status() {
  engine_read
  hosts_read $HOSTS_FILE
  hosts_parse "$REPLY" || die "$HOSTS_ERROR"
  if [[ ${1:-} == json ]]; then
    status_json
  else
    status_text
  fi
}

status_text() {
  case $S[SESSION] in
    none)       say "Sesión: ninguna" ;;
    indefinite) hhmm $S[SESSION_STARTED]; say "Sesión: sin fin (desde las $REPLY)" ;;
    timed)      hhmm $S[SESSION_ENDS]; say "Sesión: por tiempo, termina a las $REPLY" ;;
  esac
  if (( S[STOP_AT] > 0 )); then
    session_stop_time
    say "Terminación pendiente: el bloqueo termina a las $REPLY"
  fi
  if pass_active; then
    hhmm $S[PASS_UNTIL]
    say "Pase en curso: $S[PASS_GROUP], hasta las $REPLY"
  fi
  if [[ $S[SESSION] != none ]]; then
    say "Pases usados: $S[PASSES_USED] de $CFG[PASS_MAX_PER_SESSION]"
  fi
  if (( HOSTS_ACTIVE )); then
    say "Bloqueo: activo ($HOSTS_COUNT dominios)"
  else
    say "Bloqueo: inactivo"
  fi
}
