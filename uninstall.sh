#!/bin/zsh -f
# Desinstalador de efficiency-guardian. Lo ejecuta el usuario, desde la carpeta
# del repositorio:
#
#   sudo ./uninstall.sh
#
# Quita el LaunchDaemon y la regla de sudoers (primero: así nada más puede
# ejecutar el motor como root), luego el bloqueo (en el acto, sin el retraso al
# terminar) y el estado, y por último el motor, sus módulos y las listas.
# Conserva las copias de seguridad de /etc/hosts (en /var/db/efficiency-guardian/)
# y tu configuración. No borra /usr/local/sbin, /usr/local/libexec ni
# /usr/local/etc: pueden tener archivos de otros programas.

emulate -R zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
umask 022

readonly REPO=${0:A:h}
for file in lib/env.zsh lib/log.zsh lib/lock.zsh lib/hosts-block.zsh lib/hosts-write.zsh \
            install/paths.zsh install/launchdaemon.zsh; do
  source $REPO/$file
done

if (( EUID != 0 )); then die "ejecútalo con sudo: sudo ./uninstall.sh"; fi

# Antes de tocar nada: si los marcadores de hosts están dañados, no se podría
# quitar el bloqueo, así que no se desinstala nada.
hosts_read $HOSTS_FILE
hosts_parse "$REPLY" || die "$HOSTS_ERROR"

say "1. Quitar el LaunchDaemon y la regla de sudoers"
# Primero, para que ni reconcile ni un atajo vuelvan a poner el bloque mientras se quita.
daemon_unload
rm -f -- $PLIST_FILE $SUDOERS_FILE

say "2. Quitar el bloqueo y el estado"
# Con el candado del motor: si un guardian seguía en curso, se espera a que termine.
engine_lock
hosts_read $HOSTS_FILE
hosts_parse "$REPLY" || die "$HOSTS_ERROR"
if (( HOSTS_ACTIVE )); then
  hosts_write_atomic $HOSTS_FILE "$HOSTS_OUTSIDE"
  dns_flush
  log_event "uninstall: bloqueo quitado"
  say "   Quitado."
else
  say "   No había bloqueo."
fi
rm -f -- $REAL_DATA_DIR/state $REAL_DATA_DIR/lock

say "3. Quitar el motor, sus módulos y las listas"
rm -f -- $ENGINE
rm -rf -- $LIBEXEC_DIR $LISTS_DIR

say ""
say "Desinstalado. Se conservan:"
say "   las copias de seguridad de /etc/hosts, en $REAL_DATA_DIR"
say "   tu configuración, en $CONFIG_INSTALLED (bórrala con sudo rm si no la quieres)"
