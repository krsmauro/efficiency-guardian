# Sesiones: crearlas, convertirlas, terminarlas y aplicar el paso del tiempo.
#
# Solo cambia el estado en memoria (S, de state.zsh). Guardarlo y reescribir
# hosts es trabajo de engine.zsh. Cada cambio se anota en CHANGES, que
# engine_commit manda al registro del sistema.
#
# Ojo: (( ... )) "falla" cuando da 0. Por eso todas las comprobaciones van
# dentro de un if: suelto, con ERR_EXIT, terminaría el programa.

typeset -ga CHANGES=()

# session_init
# La primera vez (sin estado, o con un estado dañado) se empieza en el arranque
# actual y se CONSERVA lo que haya en hosts: con bloque (por ejemplo, tras
# actualizar desde la Fase 1), una sesión sin fin; sin bloque, sin sesión.
# Así instalar no activa ni quita el bloqueo.
session_init() {
  if (( STATE_EXISTS )); then return 0; fi
  S[BOOT_ID]=$BOOT_ID
  hosts_read $HOSTS_FILE
  hosts_parse "$REPLY" || die "$HOSTS_ERROR"
  if (( HOSTS_ACTIVE )); then
    session_new indefinite
    CHANGES+="estado nuevo: se conserva el bloqueo que había en hosts"
  fi
}

# session_new indefinite | session_new timed minutos
# Una sesión nueva empieza siempre con el contador de pases a 0.
session_new() {
  S[SESSION]=$1 S[SESSION_STARTED]=$NOW S[SESSION_ENDS]=0
  S[STOP_AT]=0 S[PASSES_USED]=0 S[PASS_UNTIL]=0
  if [[ $1 == timed ]]; then S[SESSION_ENDS]=$(( NOW + $2 * 60 )); fi
}

# session_convert minutos   (supuesto S2, confirmado por el usuario)
# La sesión sin fin pasa a terminar dentro de N minutos. Conserva los pases
# usados (así no sirve para reiniciarlos) y el pase en curso, y anula una
# terminación pendiente. Nunca termina antes que el retraso al terminar: si
# no, una duración corta sería un atajo para saltárselo.
session_convert() {
  local minutes=$1
  if (( minutes < CFG[STOP_DELAY_MINUTES] )); then minutes=$CFG[STOP_DELAY_MINUTES]; fi
  S[SESSION]=timed S[SESSION_ENDS]=$(( NOW + minutes * 60 )) S[STOP_AT]=0
}

# session_end motivo   (sin sesión, no hace nada)
session_end() {
  if [[ $S[SESSION] == none ]]; then return 0; fi
  S[SESSION]=none S[SESSION_STARTED]=0 S[SESSION_ENDS]=0
  S[STOP_AT]=0 S[PASSES_USED]=0 S[PASS_UNTIL]=0
  CHANGES+="fin de la sesión: $1"
}

# Deja en REPLY la hora (HH:MM) a la que termina de verdad una terminación
# pendiente: STOP_AT, o antes si la sesión por tiempo acaba antes.
session_stop_time() {
  local end=$S[STOP_AT]
  if [[ $S[SESSION] == timed ]] && (( S[SESSION_ENDS] < end )); then end=$S[SESSION_ENDS]; fi
  hhmm $end
}

# 0 si hay un pase en curso.
pass_active() {
  (( S[PASS_UNTIL] > NOW ))
}

# session_advance: lo que el paso del tiempo cambió desde la última vez.
# Es el corazón de reconcile, pero lo hacen todos los comandos al empezar:
# así nunca actúan sobre una sesión que ya terminó.
session_advance() {
  if (( S[STOP_AT] > 0 && S[STOP_AT] <= NOW )); then session_end "se cumplió el retraso al terminar"; fi
  if [[ $S[SESSION] == timed ]] && (( S[SESSION_ENDS] <= NOW )); then session_end "se acabó el tiempo"; fi
  if (( S[PASS_UNTIL] > 0 && S[PASS_UNTIL] <= NOW )); then
    S[PASS_UNTIL]=0
    CHANGES+="fin del pase"
  fi

  # ¿Arranque nuevo? Va después de lo anterior a propósito: si una sesión por
  # tiempo venció con el Mac apagado, ya terminó, y el arranque automático
  # puede crear la sesión sin fin.
  if [[ $S[BOOT_ID] != "$BOOT_ID" ]]; then
    if [[ $S[SESSION] == indefinite ]]; then session_end "el Mac se apagó o se reinició"; fi
    S[BOOT_ID]=$BOOT_ID
    if [[ $S[SESSION] == none && $CFG[AUTOSTART_AT_BOOT] == yes ]]; then
      session_new indefinite
      CHANGES+="arranque automático: sesión sin fin"
    fi
  fi
}
