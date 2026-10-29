# Línea de comandos: validar los argumentos y llamar al subcomando.
# Cualquier otra combinación muestra el uso y sale con 2.

cli_usage() {
  print -ru2 -- "Uso: guardian start [minutos] | stop | cancel-stop | pass [grupo] | extend [minutos]"
  print -ru2 -- "                | shorten <minutos> | status [--json] | reconcile"
  print -ru2 -- "  start              empieza una sesión sin fin, o cancela una terminación pendiente"
  print -ru2 -- "  start <minutos>    sesión por tiempo (una duración de TIMED_PRESETS)"
  print -ru2 -- "  stop               termina la sesión tras el retraso (STOP_DELAY_MINUTES)"
  print -ru2 -- "  cancel-stop        anula la terminación pendiente: la sesión sigue"
  print -ru2 -- "  pass [grupo]       pase temporal para un grupo de PASS_GROUPS (sin grupo, el primero)"
  print -ru2 -- "  extend [minutos]   la sesión por tiempo pasa a durar eso (más que ahora); sin minutos, sin fin"
  print -ru2 -- "  shorten <minutos>  la sesión por tiempo pasa a durar eso, nunca menos que el retraso"
  print -ru2 -- "  status             estado de la sesión y del bloqueo; --json para la app"
  print -ru2 -- "  reconcile          aplica lo que cambió con el tiempo (lo usa el LaunchDaemon)"
  print -ru2 -- "Todos necesitan sudo, menos status."
  exit 2
}

# MINUTES_REGEX está en config-check.zsh y GROUP_REGEX en blocklist.zsh: la
# regla de sudoers usa los mismos patrones.
cli_main() {
  case $#:${1:-} in
    1:start)       cmd_start ;;
    2:start)       if [[ $2 =~ $MINUTES_REGEX ]]; then cmd_start $2; else cli_usage; fi ;;
    1:stop)        cmd_stop ;;
    1:cancel-stop) cmd_cancel_stop ;;
    1:pass)        cmd_pass ;;
    2:pass)        if [[ $2 =~ $GROUP_REGEX ]]; then cmd_pass $2; else cli_usage; fi ;;
    1:extend)      cmd_extend ;;
    2:extend)      if [[ $2 =~ $MINUTES_REGEX ]]; then cmd_extend $2; else cli_usage; fi ;;
    2:shorten)     if [[ $2 =~ $MINUTES_REGEX ]]; then cmd_shorten $2; else cli_usage; fi ;;
    1:status)      cmd_status ;;
    2:status)      if [[ $2 == --json ]]; then cmd_status json; else cli_usage; fi ;;
    1:reconcile)   cmd_reconcile ;;
    *)             cli_usage ;;
  esac
}
