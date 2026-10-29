#!/bin/zsh -f
# Instalador de efficiency-guardian (Fase 1). Lo ejecuta el usuario, desde la
# carpeta del repositorio:
#
#   sudo ./install.sh
#
# Pasos (la lógica de cada uno vive en install/):
#   1. Comprobar que corre con sudo desde un usuario normal.
#   2. Ejecutar las pruebas como ese usuario. Si fallan, no se instala nada.
#   3. Copiar el motor, sus módulos y las listas, con dueño root.      files.zsh
#   4. Verificar que nadie más que root puede modificar lo instalado.  verify.zsh
#   5. Ofrecer quitar las líneas manuales antiguas de /etc/hosts.      migrate-hosts.zsh
#   6. Instalar la regla de sudoers: start y stop sin contraseña.      sudoers.zsh
#   7. Mostrar los siguientes pasos.
#
# El paso 4 va antes que el 6 a propósito: la regla de sudoers solo se instala
# si lo instalado es seguro. No activa el bloqueo. Se puede volver a ejecutar
# para actualizar lo instalado (por ejemplo, tras cambiar las listas).

emulate -R zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL
export PATH=/usr/bin:/bin:/usr/sbin:/sbin
umask 022

readonly REPO=${0:A:h}
for file in lib/env.zsh lib/log.zsh lib/blocklist.zsh lib/hosts-block.zsh lib/hosts-write.zsh \
            install/paths.zsh install/files.zsh install/verify.zsh install/migrate-hosts.zsh \
            install/sudoers.zsh; do
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
say "   ${${(f)test_output}[-1]}"

say "3. Copiar archivos"
install_files

say "4. Verificar permisos"
install_verify

say "5. Líneas manuales antiguas en /etc/hosts"
install_migrate_hosts

say "6. Regla de sudoers"
install_sudoers $SUDO_USER

say ""
say "Instalado. El bloqueo NO está activo todavía."
say ""
say "Siguientes pasos (verificación manual del paso 1.6, en docs/fases/fase-1-motor.md):"
say "   sudo -n $ENGINE start     # activa el bloqueo sin pedir contraseña"
say "   $ENGINE status            # sin sudo"
say "   sudo -n $ENGINE stop      # lo quita"
say "Después: la Fase 2 (docs/fases/fase-2-interruptor.md)."
