# Paso 8 del instalador: la regla de sudoers que deja ejecutar los comandos del
# motor sin contraseña (para Atajos y la app).
#
# No depende de la configuración: cambiar TIMED_PRESETS o PASS_GROUPS no obliga
# a volver a instalar. Cómo compara sudo (man sudoers y su código, match_command.c
# y toke.l; verificado el 2026-10-29 tras un fallo en el Mac):
#   - Los "argumentos" de una entrada son TODO lo que va tras la ruta, unido con
#     espacios. "G stop" admite solo "stop", exacto.
#   - Son un patrón (ERE) solo si EMPIEZAN con ^ y terminan con $: por eso el
#     subcomando va dentro ("G ^start [1-9]...$"). "G start ^[1-9]...$" se lee
#     como texto literal y no admite nada.
# Los patrones son los mismos con los que el motor valida su línea de comandos
# (MINUTES_REGEX y GROUP_REGEX), y después rechaza lo que no esté en la
# configuración, que solo root puede cambiar. tests/test-sudoers.zsh imita esa
# comparación. "status" no hace falta (se usa sin sudo) y "reconcile" solo lo
# ejecuta el LaunchDaemon.
# Un error de sintaxis en sudoers puede dejar sudo inutilizable, así que la
# regla se valida dos veces con visudo y, si algo falla, se borra.

# sudoers_rule usuario → imprime el contenido del archivo.
sudoers_rule() {
  local g=$ENGINE minutes=${MINUTES_REGEX#^} group=${GROUP_REGEX#^}
  local -a commands=(
    "$g start" "$g ^start $minutes"
    "$g stop" "$g cancel-stop"
    "$g pass" "$g ^pass $group"
    "$g extend" "$g ^extend $minutes"
    "$g ^shorten $minutes"
  )
  print -r -- "# Generado por efficiency-guardian (install.sh). No editar a mano: vuelve a ejecutar el instalador."
  print -r -- "$1 ALL=(root) NOPASSWD: ${(j:, :)commands}"
}

install_sudoers() {
  local user=$1 tmp

  # El nombre va dentro de sudoers: solo se aceptan nombres de usuario normales.
  if [[ ! $user =~ '^[a-z_][a-z0-9_.-]*$' ]]; then die "nombre de usuario inesperado: $user"; fi
  if ! id -u $user > /dev/null 2>&1; then die "no existe el usuario $user"; fi

  tmp=$(mktemp /tmp/efficiency-guardian-sudoers.XXXXXX)
  sudoers_rule $user > $tmp
  if ! visudo -c -q -f $tmp; then
    rm -f -- $tmp
    die "la regla generada no es válida; no se instaló"
  fi
  install -o root -g wheel -m 440 $tmp $SUDOERS_FILE
  rm -f -- $tmp

  if ! visudo -c -q; then
    rm -f -- $SUDOERS_FILE
    die "sudo no aceptó la configuración completa; se quitó la regla"
  fi
  say "   $SUDOERS_FILE"
  say "   $user puede ejecutar sin contraseña: sudo -n $ENGINE start [minutos] | stop | cancel-stop"
  say "     | pass [grupo] | extend [minutos] | shorten <minutos>"
  say "     (el motor solo acepta las duraciones y los grupos de la configuración)"
}
