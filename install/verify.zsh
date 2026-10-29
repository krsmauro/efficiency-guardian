# Paso 5 del instalador: comprobar que nadie más que root puede modificar lo que
# se ejecuta como root. Con una sola carpeta escribible por el usuario, cualquier
# programa suyo (incluido un malware) podría cambiar el motor y, gracias a la
# regla de sudoers o al LaunchDaemon, obtener root sin contraseña.
#
# Si algo falla, se quitan la regla de sudoers y el LaunchDaemon (si quedaban de
# una instalación anterior) y se aborta antes de instalar los nuevos.

# is_root_only ruta
# 0 si es de root, no es un enlace y ni el grupo ni otros pueden escribirla.
# (bin/guardian hace la misma comprobación antes de cargar sus módulos.)
is_root_only() {
  local owner mode
  if [[ ! -e $1 || -L $1 ]]; then return 1; fi
  owner=$(stat -f %u -- $1)
  mode=$(stat -f %Lp -- $1)
  if (( owner != 0 || (8#$mode & 8#022) != 0 )); then return 1; fi
  return 0
}

install_verify() {
  local target problems=0
  local -a targets=(
    /usr/local $SBIN_DIR $ENGINE
    /usr/local/libexec $LIBEXEC_DIR $LIB_DIR $LIB_DIR/*(N)
    /usr/local/etc $ETC_DIR $CONFIG_INSTALLED $LISTS_DIR $LISTS_DIR/*(N)
    $REAL_DATA_DIR $DAEMONS_DIR $PLIST_FILE
  )

  for target in $targets; do
    if ! is_root_only $target; then
      err "inseguro: $target ($(stat -f '%Su:%Sg %Sp' -- $target 2>/dev/null || print -n 'no existe'))"
      problems=1
    fi
  done

  if (( problems )); then
    rm -f -- $SUDOERS_FILE
    daemon_unload
    rm -f -- $PLIST_FILE
    die "instalación insegura: no hay regla de sudoers ni LaunchDaemon. Corrige los permisos y vuelve a ejecutar."
  fi
  say "   $#targets rutas revisadas: son de root y nadie más puede modificarlas."
}
