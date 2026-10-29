# status --json: lo mismo que status, en JSON, para la app de la Fase 5.
#
# Las horas son epoch (segundos desde 1970); 0 significa "no hay". "now" es la
# hora del motor. "blocking" y "blocked_domains" son lo que hay en hosts ahora.
# Todos los valores son números, true/false o textos ya validados (el tipo de
# sesión y los nombres de grupo), así que no hace falta escapar nada.

status_json() {
  local -a groups=(\"${^CFG_PASS_GROUPS}\")
  print -r -- "{"
  print -r -- "  \"now\": $NOW,"
  print -r -- "  \"session\": \"$S[SESSION]\","
  print -r -- "  \"session_started\": $S[SESSION_STARTED],"
  print -r -- "  \"session_ends\": $S[SESSION_ENDS],"
  print -r -- "  \"stop_at\": $S[STOP_AT],"
  print -r -- "  \"pass_until\": $S[PASS_UNTIL],"
  print -r -- "  \"passes_used\": $S[PASSES_USED],"
  print -r -- "  \"passes_max\": $CFG[PASS_MAX_PER_SESSION],"
  print -r -- "  \"pass_minutes\": $CFG[PASS_MINUTES],"
  print -r -- "  \"pass_groups\": [${(j:, :)groups}],"
  print -r -- "  \"stop_delay_minutes\": $CFG[STOP_DELAY_MINUTES],"
  print -r -- "  \"timed_lock\": $(json_bool $CFG[TIMED_LOCK]),"
  print -r -- "  \"timed_presets\": [${(j:, :)CFG_PRESETS}],"
  print -r -- "  \"autostart_at_boot\": $(json_bool $CFG[AUTOSTART_AT_BOOT]),"
  print -r -- "  \"blocking\": $(json_bool $(( HOSTS_ACTIVE ))),"
  print -r -- "  \"blocked_domains\": $HOSTS_COUNT"
  print -r -- "}"
}

# json_bool yes|no|1|0 → true o false
json_bool() {
  if [[ $1 == (yes|1) ]]; then print -rn -- true; else print -rn -- false; fi
}
