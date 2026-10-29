# Subcomando extend [minutos]: alargar la sesión por tiempo en curso (D16).
#
#   extend <min>  La sesión pasa a durar <min> en total, contados desde que
#                 empezó la parte por tiempo (TIMED_STARTED), igual que shorten.
#                 <min> debe estar en TIMED_PRESETS y ser más de lo que dura.
#   extend        La sesión pasa a ser sin fin ("Sin fin" en la app). Conserva
#                 los pases usados y el pase en curso. Como toda sesión sin fin,
#                 termina con stop o al apagar el Mac.
# Con candado se puede alargar (es más enfoque), pero no pasar a sin fin: una
# sesión sin fin se termina con stop, y eso sería saltarse el candado.
# Nada de esto se puede durante una terminación pendiente: primero cancel-stop.

cmd_extend() {
  local minutes=${1:-} current message
  engine_begin
  if [[ -n $minutes ]]; then config_require_preset $minutes; fi
  session_require_timed alargar

  if [[ -z $minutes ]]; then
    session_check_lock
    S[SESSION]=indefinite S[SESSION_ENDS]=0 S[TIMED_STARTED]=0
    CHANGES+="extend: la sesión pasa a ser sin fin"
    message="La sesión ahora es sin fin: sigue hasta que la termines o apagues el Mac."
    message+=" Pases usados: $S[PASSES_USED] de $CFG[PASS_MAX_PER_SESSION]."
  else
    current=$(( S[SESSION_ENDS] - S[TIMED_STARTED] ))
    if (( minutes * 60 <= current )); then
      die "la sesión dura $(( current / 60 )) min: solo se puede alargar a más"
    fi
    S[SESSION_ENDS]=$(( S[TIMED_STARTED] + minutes * 60 ))
    hhmm $S[SESSION_ENDS]
    CHANGES+="extend $minutes: la sesión termina a las $REPLY"
    message="Sesión alargada a $minutes min: termina a las $REPLY."
  fi

  engine_commit
  say "$message"
}
