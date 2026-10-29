# Línea de comandos: validar los argumentos y llamar al subcomando.
# Cualquier otra combinación muestra el uso y sale con 2.

cli_usage() {
  print -ru2 -- "Uso: guardian start [minutos] | stop | cancel-stop | pass | status [--json] | reconcile"
  print -ru2 -- "  start            empieza una sesión sin fin, o cancela una terminación pendiente"
  print -ru2 -- "  start <minutos>  sesión por tiempo (una duración de TIMED_PRESETS)"
  print -ru2 -- "  stop             termina la sesión tras el retraso (STOP_DELAY_MINUTES)"
  print -ru2 -- "  cancel-stop      anula la terminación pendiente: la sesión sigue"
  print -ru2 -- "  pass             pase temporal para PASS_GROUPS (por defecto, YouTube)"
  print -ru2 -- "  status           estado de la sesión y del bloqueo; --json para la app"
  print -ru2 -- "  reconcile        aplica lo que cambió con el tiempo (lo usa el LaunchDaemon)"
  print -ru2 -- "Todos necesitan sudo, menos status."
  exit 2
}

cli_main() {
  case $#:${1:-} in
    1:start)       cmd_start ;;
    2:start)       if [[ $2 =~ '^[1-9][0-9]{0,2}$' ]]; then cmd_start $2; else cli_usage; fi ;;
    1:stop)        cmd_stop ;;
    1:cancel-stop) cmd_cancel_stop ;;
    1:pass)        cmd_pass ;;
    1:status)      cmd_status ;;
    2:status)      if [[ $2 == --json ]]; then cmd_status json; else cli_usage; fi ;;
    1:reconcile)   cmd_reconcile ;;
    *)             cli_usage ;;
  esac
}
