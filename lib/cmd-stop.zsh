# Subcomando stop: pedir el fin de la sesión.
#
# Con retraso (STOP_DELAY_MINUTES > 0; por defecto 5), el bloqueo sigue hasta
# STOP_AT por si cambias de opinión: cancel-stop o start lo anulan. Al llegar
# la hora, reconcile termina la sesión. Con 0, termina ya. Pedirlo otra vez no
# alarga ni acorta la espera.
# Una sesión por tiempo con TIMED_LOCK=yes no se puede terminar antes de la hora.
# Sin sesión no hay nada que terminar, pero hosts se pone al día igual. No lee
# las listas: aunque estén dañadas, stop siempre puede desbloquear.
# (Las piezas compartidas con shorten están en session-ending.zsh.)

cmd_stop() {
  local message
  engine_begin

  if [[ $S[SESSION] == none ]]; then
    message="No había sesión."
  else
    session_check_lock
    if (( S[STOP_AT] > 0 )); then
      session_stop_time
      message="Ya había una terminación pendiente: el bloqueo termina a las $REPLY."
    else
      session_request_stop stop
      message=$REPLY
    fi
  fi

  engine_commit
  say "$message"
}
