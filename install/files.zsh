# Paso 4 del instalador: copiar el motor, sus módulos, las listas, la
# configuración (solo si no existe) y el LaunchDaemon (sin cargarlo), con dueño root.

# Carpetas que pueden compartir otros programas: se crean si faltan, pero si ya
# existen no se tocan. El paso 5 comprueba que sean seguras.
readonly SHARED_DIRS=(/usr/local/sbin /usr/local/libexec /usr/local/etc)

install_files() {
  local dir
  for dir in $SHARED_DIRS; do
    if [[ ! -d $dir ]]; then install -d -o root -g wheel -m 755 $dir; fi
  done

  # Carpetas propias: siempre root:wheel 755. La de datos también es 755 (la
  # app lee el estado sin root); las copias de seguridad que hay dentro son 600.
  install -d -o root -g wheel -m 755 $LIBEXEC_DIR $LIB_DIR $ETC_DIR $LISTS_DIR $REAL_DATA_DIR

  # Quitar restos de una instalación anterior (por ejemplo, un grupo que ya no existe).
  rm -f -- $LIB_DIR/*(N) $LISTS_DIR/*(N)

  install -o root -g wheel -m 644 $REPO/lib/*.zsh $LIB_DIR/
  install -o root -g wheel -m 644 $REPO/blocklists/*.txt $LISTS_DIR/
  install -o root -g wheel -m 755 $REPO/bin/guardian $ENGINE
  install -o root -g wheel -m 644 $REPO/launchd/$DAEMON_LABEL.plist $PLIST_FILE

  # La configuración es del usuario: nunca se sobrescribe.
  if [[ -e $CONFIG_INSTALLED ]]; then
    say "   Configuración: $CONFIG_INSTALLED (se conserva la tuya)"
  else
    install -o root -g wheel -m 644 $REPO/config.default $CONFIG_INSTALLED
    say "   Configuración: $CONFIG_INSTALLED (valores por defecto)"
  fi

  say "   Motor:   $ENGINE"
  say "   Módulos: $LIB_DIR"
  say "   Listas:  $LISTS_DIR"
  say "   LaunchDaemon: $PLIST_FILE (se carga en el paso 7)"
}
