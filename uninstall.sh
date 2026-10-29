#!/bin/zsh -f
# Desinstalador de efficiency-guardian. Lo ejecuta el usuario, desde la carpeta
# del repositorio:
#
#   sudo ./uninstall.sh
#
# Quita el bloqueo, la regla de sudoers, el motor, sus módulos y las listas.
# Conserva /var/db/efficiency-guardian/ (copias de seguridad de /etc/hosts).
# No borra /usr/local/sbin, /usr/local/libexec ni /usr/local/etc: pueden tener
# archivos de otros programas.

emulate -R zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
umask 022

readonly REPO=${0:A:h}
for file in lib/env.zsh lib/log.zsh lib/hosts-block.zsh lib/hosts-write.zsh install/paths.zsh; do
  source $REPO/$file
done

if (( EUID != 0 )); then die "ejecútalo con sudo: sudo ./uninstall.sh"; fi

say "1. Quitar el bloqueo"
if [[ -x $ENGINE ]] && $ENGINE stop; then
  :
else
  # Sin el motor no hay otra forma de quitar el bloque: si sigue ahí, no se desinstala.
  hosts_read $HOSTS_FILE
  hosts_parse "$REPLY" || die "$HOSTS_ERROR"
  if (( HOSTS_ACTIVE )); then
    die "no se pudo quitar el bloqueo de $HOSTS_FILE; no se desinstaló nada"
  fi
  say "   No había bloqueo."
fi

say "2. Quitar la regla de sudoers"
rm -f -- $SUDOERS_FILE

say "3. Quitar el motor, sus módulos y las listas"
rm -f -- $ENGINE
rm -rf -- $LIBEXEC_DIR $ETC_DIR

say ""
say "Desinstalado. Las copias de seguridad siguen en $REAL_DATA_DIR."
