# Subcomando cancel-stop: anular la terminación pendiente ("seguir trabajando").
# La sesión sigue como estaba. Si no había terminación pendiente, no hace nada.

cmd_cancel_stop() {
  local message="No había ninguna terminación pendiente."
  engine_begin
  if (( S[STOP_AT] > 0 )); then
    S[STOP_AT]=0
    CHANGES+="cancel-stop: la sesión sigue"
    message="Terminación cancelada: la sesión sigue."
  fi
  engine_commit
  say "$message"
}
