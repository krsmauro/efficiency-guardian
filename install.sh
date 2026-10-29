#!/bin/zsh -f
# Instalador de efficiency-guardian (Fases 1 y 4). Lo ejecuta el usuario, desde
# la carpeta del repositorio:
#
#   sudo ./install.sh
#
# Pasos (la lógica de cada uno vive en install/):
#   1. Comprobar que corre con sudo desde un usuario normal.
#   2. Ejecutar las pruebas como ese usuario. Si fallan, no se instala nada.
#   3. Validar la configuración (la instalada o la de por defecto) contra
#      las listas que se van a instalar, ANTES de tocar nada.         lib/config*.zsh
#   4. Descargar el LaunchDaemon (si estaba) y copiar el motor, sus módulos,
#      las listas, la configuración y el plist, con dueño root.       files.zsh
#   5. Verificar que nadie más que root puede modificar lo instalado. verify.zsh
#   6. Ofrecer quitar las líneas manuales antiguas de /etc/hosts.     migrate-hosts.zsh
#   7. Cargar el LaunchDaemon (reconcile cada 30 s).                  launchdaemon.zsh
#   8. Instalar la regla de sudoers (no depende de la configuración). sudoers.zsh
#   9. Mostrar los siguientes pasos.
#
# El paso 5 va antes que el 7 y el 8 a propósito: la regla de sudoers y el
# LaunchDaemon solo se instalan si lo instalado es seguro. Y el 7 va antes que
# el 8 para que, si falla la regla, el LaunchDaemon no quede descargado.
# Instalar no activa ni quita el bloqueo: si estaba activo, sigue activo. Con
# AUTOSTART_AT_BOOT=yes, la sesión automática empieza en el siguiente arranque.
# Se puede volver a ejecutar para actualizar lo instalado (por ejemplo, tras
# cambiar las listas o con una versión nueva del motor).

emulate -R zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
umask 022

readonly REPO=${0:A:h}
for file in lib/env.zsh lib/log.zsh lib/config.zsh lib/config-check.zsh lib/blocklist.zsh lib/hosts-block.zsh \
            lib/hosts-write.zsh install/paths.zsh install/files.zsh install/verify.zsh \
            install/migrate-hosts.zsh install/sudoers.zsh install/launchdaemon.zsh; do
  source $REPO/$file
done

say "1. Comprobaciones"
if (( EUID != 0 )); then die "ejecútalo con sudo: sudo ./install.sh"; fi
if [[ -z ${SUDO_USER:-} || $SUDO_USER == root ]]; then
  die "ejecútalo con sudo desde tu usuario, no directamente como root"
fi
say "   Usuario: $SUDO_USER"

say "2. Pruebas (como $SUDO_USER, sin root)"
if ! test_output=$(sudo -u $SUDO_USER /bin/zsh -f $REPO/tests/run.zsh 2>&1); then
  print -rl -- ${${(f)test_output}:#  ok *}     # todo menos las líneas que pasaron
  die "las pruebas fallan: no se instaló nada"
fi
say "   ${${(@f)test_output}[-1]}"

say "3. Revisar la configuración"
if [[ -e $CONFIG_INSTALLED ]]; then config_source=$CONFIG_INSTALLED; else config_source=$REPO/config.default; fi
if ! { config_load $config_source && config_check_pass_groups $REPO/blocklists }; then
  die "corrige $config_source (con sudo) y vuelve a ejecutar el instalador: no se instaló nada"
fi
say "   $config_source: válida. Duraciones: ${(j:, :)CFG_PRESETS} min; retraso al terminar: $CFG[STOP_DELAY_MINUTES] min."

say "4. Copiar archivos"
daemon_unload
install_files

say "5. Verificar permisos"
install_verify

say "6. Líneas manuales antiguas en /etc/hosts"
install_migrate_hosts

say "7. LaunchDaemon"
daemon_load

say "8. Regla de sudoers"
install_sudoers $SUDO_USER

say ""
say "Instalado. Estado actual:"
sudo -u $SUDO_USER $ENGINE status | sed 's/^/   /' || warn "no se pudo mostrar el estado: prueba '$ENGINE status'"
say ""
say "Siguientes pasos (verificación manual: 1.6 en docs/fases/fase-1-motor.md"
say "y 4.4 en docs/fases/fase-4-sesiones-y-tiempo.md):"
say "   sudo -n $ENGINE start       # sesión sin fin, sin pedir contraseña"
say "   $ENGINE status              # sin sudo"
say "   sudo -n $ENGINE stop        # termina tras el retraso; cancel-stop lo anula"
