# Paso 6 del instalador: la regla de sudoers que deja ejecutar "guardian start"
# y "guardian stop" sin contraseña (para Atajos y, más adelante, la app).
#
# Solo esos dos comandos, con los argumentos exactos. "guardian status" no hace
# falta (se usa sin sudo), y con cualquier otro argumento sudo pide contraseña.
# Un error de sintaxis en sudoers puede dejar sudo inutilizable, así que la
# regla se valida dos veces con visudo y, si algo falla, se borra.

# sudoers_rule usuario → imprime el contenido del archivo.
sudoers_rule() {
  print -r -- "# Generado por efficiency-guardian (install.sh). No editar a mano: vuelve a ejecutar el instalador."
  print -r -- "$1 ALL=(root) NOPASSWD: $ENGINE start, $ENGINE stop"
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
  say "   $user puede ejecutar sin contraseña: sudo -n $ENGINE start (o stop)"
}
