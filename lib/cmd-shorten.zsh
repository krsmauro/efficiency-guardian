# Subcomando shorten <minutos>: acortar la sesión por tiempo en curso (D16).
#
# La sesión pasa a durar <minutos> (de TIMED_PRESETS y menos que ahora),
# contados desde que empezó la parte por tiempo: TIMED_STARTED, porque una
# sesión sin fin convertida (S2) conserva su SESSION_STARTED.
# - Si esa hora llega después que el retraso al terminar, el fin pasa a esa hora.
# - Si no (ya pasó, o llegaría antes), es igual que stop: una terminación
#   pendiente con el retraso, que cancel-stop anula. Así acortar nunca sirve
#   para saltarse el retraso (aceptado por el usuario el 2026-10-29).
# Con TIMED_LOCK=yes se rechaza, como stop.

cmd_shorten() {
  local minutes=$1 started target message
  engine_begin
  config_require_preset $minutes
  session_require_timed acortar
  session_check_lock

  started=$S[TIMED_STARTED]
  if (( minutes * 60 >= S[SESSION_ENDS] - started )); then
    die "la sesión dura $(( (S[SESSION_ENDS] - started) / 60 )) min: solo se puede acortar a menos"
  fi

  target=$(( started + minutes * 60 ))
  if (( target > NOW + CFG[STOP_DELAY_MINUTES] * 60 )); then
    S[SESSION_ENDS]=$target
    hhmm $target
    CHANGES+="shorten $minutes: la sesión termina a las $REPLY"
    message="Sesión acortada a $minutes min: termina a las $REPLY."
  else
    if (( target <= NOW )); then
      message="Ya pasaron $minutes min."
    else
      message="A $minutes min, terminaría antes que el retraso al terminar."
    fi
    session_request_stop "shorten $minutes"
    message+=" $REPLY"
  fi

  engine_commit
  say "$message"
}
