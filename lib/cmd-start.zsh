# Subcomando start [minutos]: empezar una sesión, o seguir en la que hay.
#
#   start        Sin sesión: una sesión sin fin. Con sesión: no la cambia, pero
#                cancela una terminación pendiente ("sigo trabajando").
#                Repetirlo no cambia nada (Atajos a veces envía dos eventos).
#   start <min>  <min> debe estar en TIMED_PRESETS. Sin sesión: una sesión por
#                tiempo. Con una sin fin: la convierte (S2). Con otra por
#                tiempo: error (no se puede acortar ni alargar).
# En todos los casos hosts se pone al día (por ejemplo, si cambiaron las listas).

cmd_start() {
  local minutes=${1:-} message
  engine_begin
  if [[ -n $minutes ]] && (( ! ${CFG_PRESETS[(Ie)$minutes]} )); then
    die "$minutes min no es una duración permitida (TIMED_PRESETS: ${(j:, :)CFG_PRESETS})"
  fi

  case $S[SESSION]:${minutes:+timed} in
    none:)
      session_new indefinite
      CHANGES+="start: sesión sin fin"
      message="Sesión sin fin iniciada." ;;
    none:timed)
      session_new timed $minutes
      hhmm $S[SESSION_ENDS]
      CHANGES+="start $minutes: sesión por tiempo hasta las $REPLY"
      message="Sesión de $minutes min iniciada: termina a las $REPLY." ;;
    indefinite:timed)
      session_convert $minutes
      hhmm $S[SESSION_ENDS]
      CHANGES+="start $minutes: la sesión sin fin ahora termina a las $REPLY"
      message="La sesión sin fin ahora termina a las $REPLY."
      message+=" Pases usados: $S[PASSES_USED] de $CFG[PASS_MAX_PER_SESSION]." ;;
    timed:timed)
      hhmm $S[SESSION_ENDS]
      die "ya hay una sesión por tiempo: termina a las $REPLY" ;;
    *)
      if (( S[STOP_AT] > 0 )); then
        S[STOP_AT]=0
        CHANGES+="start: terminación cancelada"
        message="Terminación cancelada: la sesión sigue."
      else
        message="Ya había una sesión."
      fi ;;
  esac

  engine_commit
  say "$message $PLAN_COUNT dominios bloqueados."
}
