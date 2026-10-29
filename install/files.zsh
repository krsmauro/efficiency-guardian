# Paso 3 del instalador: copiar el motor, sus módulos y las listas, con dueño root.

# Carpetas que pueden compartir otros programas: se crean si faltan, pero si ya
# existen no se tocan. El paso 4 comprueba que sean seguras.
readonly SHARED_DIRS=(/usr/local/sbin /usr/local/libexec /usr/local/etc)

install_files() {
  local dir
  for dir in $SHARED_DIRS; do
    if [[ ! -d $dir ]]; then install -d -o root -g wheel -m 755 $dir; fi
  done

  # Carpetas propias: siempre root:wheel. Las copias de seguridad, solo para root.
  install -d -o root -g wheel -m 755 $LIBEXEC_DIR $LIB_DIR $ETC_DIR $LISTS_DIR
  install -d -o root -g wheel -m 700 $REAL_DATA_DIR

  # Quitar restos de una instalación anterior (por ejemplo, un grupo que ya no existe).
  rm -f -- $LIB_DIR/*(N) $LISTS_DIR/*(N)

  install -o root -g wheel -m 644 $REPO/lib/*.zsh $LIB_DIR/
  install -o root -g wheel -m 644 $REPO/blocklists/*.txt $LISTS_DIR/
  install -o root -g wheel -m 755 $REPO/bin/guardian $ENGINE

  say "   Motor:   $ENGINE"
  say "   Módulos: $LIB_DIR"
  say "   Listas:  $LISTS_DIR"
}
