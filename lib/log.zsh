# Mensajes para la persona y registro en el sistema.
#
# Para ver el registro (en zsh, "log" a secas es otro comando: usar /usr/bin/log):
#   /usr/bin/log show --last 1h --style compact \
#     --predicate 'process == "logger" AND eventMessage BEGINSWITH "efficiency-guardian"'

# Mensaje normal (salida estándar).
say() {
  print -r -- "$*"
}

# Aviso o error que no detiene el programa (salida de errores).
warn() {
  print -ru2 -- "guardian: aviso: $*"
}

err() {
  print -ru2 -- "guardian: error: $*"
}

# Error que detiene el programa con código 1.
die() {
  err "$@"
  exit 1
}

# Registra un evento en el registro del sistema. Solo siendo root: las pruebas
# no ensucian el registro. Si falla, avisa pero no detiene nada.
# El nombre va también dentro del mensaje: la etiqueta de -t no aparece en el
# texto que filtra "log show" (verificado el 2026-10-29).
log_event() {
  if (( IS_ROOT )); then
    logger -t efficiency-guardian "efficiency-guardian: $*" || warn "no se pudo escribir en el registro del sistema"
  fi
  return 0
}
