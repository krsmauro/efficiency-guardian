# Cuándo termina una sesión en curso: pedir su fin con el retraso, el candado
# y lo que exigen alargar y acortar. Lo usan stop, extend y shorten.
# Como session.zsh, solo cambia el estado en memoria (S).

# El comando que el motor sugiere para anular una terminación pendiente. Ruta
# completa y con sudo: /usr/local/sbin no está en el PATH de macOS (fallo de la
# verificación manual 4.4).
readonly CANCEL_STOP_HINT="sudo /usr/local/sbin/guardian cancel-stop"

# Deja en REPLY la hora (HH:MM) a la que termina de verdad una terminación
# pendiente: STOP_AT, o antes si la sesión por tiempo acaba antes.
session_stop_time() {
  local end=$S[STOP_AT]
  if [[ $S[SESSION] == timed ]] && (( S[SESSION_ENDS] < end )); then end=$S[SESSION_ENDS]; fi
  hhmm $end
}

# session_request_stop motivo
# Pide el fin de la sesión: el bloqueo sigue STOP_DELAY_MINUTES por si cambias
# de opinión (cancel-stop o start lo anulan); con 0, termina ya. Deja en REPLY
# el mensaje para la persona.
session_request_stop() {
  if (( CFG[STOP_DELAY_MINUTES] == 0 )); then
    session_end "$1"
    REPLY="Sesión terminada: se quitó el bloqueo."
    return 0
  fi
  S[STOP_AT]=$(( NOW + CFG[STOP_DELAY_MINUTES] * 60 ))
  session_stop_time
  CHANGES+="$1: el bloqueo termina a las $REPLY"
  REPLY="El bloqueo sigue hasta las $REPLY, por si cambias de opinión. Para seguir trabajando: $CANCEL_STOP_HINT"
}

# Con TIMED_LOCK=yes, una sesión por tiempo no se puede terminar, acortar ni
# pasar a sin fin.
session_check_lock() {
  if [[ $S[SESSION] == timed && $CFG[TIMED_LOCK] == yes ]]; then
    hhmm $S[SESSION_ENDS]
    die "sesión con candado: termina a las $REPLY"
  fi
}

# session_require_timed alargar|acortar
# Solo con una sesión por tiempo, y sin terminación pendiente: primero hay que
# anularla (así una sola acción nunca hace dos cosas).
session_require_timed() {
  if [[ $S[SESSION] != timed ]]; then die "solo se puede $1 una sesión por tiempo"; fi
  if (( S[STOP_AT] > 0 )); then
    session_stop_time
    die "no se puede $1 con una terminación pendiente (termina a las $REPLY): anúlala primero (cancel-stop)"
  fi
}
