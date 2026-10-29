# Subcomando reconcile: lo ejecuta el LaunchDaemon cada 30 s y al arrancar el Mac.
#
# No necesita lógica propia: engine_begin ya aplica lo que el paso del tiempo
# cambió (session_advance, en session.zsh) y engine_commit deja hosts como
# corresponde. Eso incluye restaurar el bloque si alguien editó hosts a mano.
# Si no cambió nada, no escribe nada.
# No está en la regla de sudoers: solo lo ejecuta launchd, como root.

cmd_reconcile() {
  local change
  engine_begin
  engine_commit
  for change in $CHANGES; do say "$change"; done
}
