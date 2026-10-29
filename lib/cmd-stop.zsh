# Subcomando stop: pedir el fin de la sesión.
#
# Con retraso (STOP_DELAY_MINUTES > 0; por defecto 5), el bloqueo sigue hasta
# STOP_AT por si cambias de opinión: cancel-stop o start lo anulan. Al llegar
# la hora, reconcile termina la sesión. Con 0, termina ya. Pedirlo otra vez no
# alarga ni acorta la espera.
# Una sesión por tiempo con TIMED_LOCK=yes no se puede terminar antes de la hora.
# Sin sesión no hay nada que terminar, pero hosts se pone al día igual. No lee
# las listas: aunque estén dañadas, stop siempre puede desbloquear.

cmd_stop() {
  local message
  engine_begin

  if [[ $S[SESSION] == none ]]; then
    message="No había sesión."
  elif [[ $S[SESSION] == timed && $CFG[TIMED_LOCK] == yes ]]; then
    hhmm $S[SESSION_ENDS]
    die "sesión con candado: termina a las $REPLY"
  elif (( S[STOP_AT] > 0 )); then
    session_stop_time
    message="Ya había una terminación pendiente: el bloqueo termina a las $REPLY."
  elif (( CFG[STOP_DELAY_MINUTES] == 0 )); then
    session_end "stop"
    message="Sesión terminada: se quitó el bloqueo."
  else
    S[STOP_AT]=$(( NOW + CFG[STOP_DELAY_MINUTES] * 60 ))
    session_stop_time
    CHANGES+="stop: el bloqueo termina a las $REPLY"
    message="El bloqueo sigue hasta las $REPLY, por si cambias de opinión."
    message+=" Para seguir trabajando: guardian cancel-stop."
  fi

  engine_commit
  say "$message"
}
