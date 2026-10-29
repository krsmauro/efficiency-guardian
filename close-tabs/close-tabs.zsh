#!/bin/zsh -f
# efficiency-guardian: cierra las pestañas abiertas de los sitios bloqueados (Fase 3).
#
# Corre como el USUARIO, nunca como root (cada 15 s, desde un LaunchAgent). Pasos:
#   1. Lee el bloque gestionado de /etc/hosts. Sin bloque, sale sin hacer nada.
#      Así respeta los pases: un grupo con pase no está en el bloque.
#   2. Por cada navegador ABIERTO, ejecuta los .js de esta carpeta con osascript.
#      Los cerrados se saltan: hablarles los abriría.
#   3. Escribe, y deja en el registro del sistema, cuántas pestañas cerró y los errores.
# Sale con 1 si algo falló, y con 0 si no.
#
# Para ver el registro (como el del motor, ver lib/log.zsh):
#   /usr/bin/log show --last 1h --style compact \
#     --predicate 'process == "logger" AND eventMessage BEGINSWITH "efficiency-guardian: close-tabs"'
#
# Para pruebas, estas variables cambian el hosts y los comandos. Son inofensivas,
# porque este script no tiene más permisos que el usuario que lo ejecuta:
#   GUARDIAN_HOSTS_FILE, GUARDIAN_OSASCRIPT, GUARDIAN_LSAPPINFO
# Con GUARDIAN_HOSTS_FILE no se escribe en el registro del sistema.

emulate -R zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL
export PATH=/usr/bin:/bin:/usr/sbin:/sbin LC_ALL=C

readonly HERE=${0:A:h}
readonly HOSTS=${GUARDIAN_HOSTS_FILE:-/etc/hosts}
readonly OSASCRIPT=${GUARDIAN_OSASCRIPT:-/usr/bin/osascript}
readonly LSAPPINFO=${GUARDIAN_LSAPPINFO:-/usr/bin/lsappinfo}
readonly BROWSERS=(com.apple.Safari com.google.Chrome com.brave.Browser com.vivaldi.Vivaldi org.chromium.Thorium)
readonly -A NAMES=(
  com.apple.Safari Safari  com.google.Chrome Chrome  com.brave.Browser Brave
  com.vivaldi.Vivaldi Vivaldi  org.chromium.Thorium Thorium
)

# report salida mensaje: salida es "out" (normal) o "err" (error).
report() {
  local stream=$1
  shift
  if [[ $stream == err ]]; then print -ru2 -- "close-tabs: $*"; else print -r -- "close-tabs: $*"; fi
  if [[ -z ${GUARDIAN_HOSTS_FILE:-} ]]; then
    logger -t efficiency-guardian "efficiency-guardian: close-tabs: $*" || true
  fi
}

if (( EUID == 0 )); then
  print -ru2 -- "close-tabs: no se ejecuta como root: los permisos de Automatización son del usuario"
  exit 1
fi

# El bloque se lee con el mismo módulo que usa el motor. Instalado, ../lib es
# /usr/local/libexec/efficiency-guardian/lib; en el repositorio, lib/.
for file in $HERE/../lib/hosts-block.zsh $HERE/{match,browser,run}.js $HOSTS; do
  if [[ ! -r $file ]]; then report err "no se puede leer $file"; exit 1; fi
done
source $HERE/../lib/hosts-block.zsh

# 1. Dominios bloqueados ahora mismo. (Se lee fuera del "if": dentro, un error
# de lectura contaría como "falso" y no detendría el script.)
content=$(<$HOSTS)
if ! hosts_parse "$content"; then report err "$HOSTS_ERROR"; exit 1; fi
if (( $#HOSTS_DOMAINS == 0 )); then exit 0; fi

# 2. Cada navegador abierto. Los .js se leen una vez y se pasan con -e.
scripts=(-e "$(<$HERE/match.js)" -e "$(<$HERE/browser.js)" -e "$(<$HERE/run.js)")
failed=0
for bundle in $BROWSERS; do
  name=$NAMES[$bundle]
  # lsappinfo escribe una línea si la app está abierta, y nada si no.
  if [[ -z $($LSAPPINFO find bundleid=$bundle 2>/dev/null) ]]; then continue; fi

  if output=$($OSASCRIPT -l JavaScript "${scripts[@]}" $bundle "${HOSTS_DOMAINS[@]}" 2>&1); then
    case $output in
      (0) ;;
      (<1->) report out "$name: $output pestañas cerradas" ;;
      (*) failed=1; report err "$name: respuesta inesperada: $output" ;;
    esac
  else
    failed=1
    report err "$name: $output"
    if [[ $output == *-1743* ]]; then
      report err "$name: falta el permiso de Automatización (Ajustes del Sistema →" \
        "Privacidad y seguridad → Automatización)"
    fi
  fi
done
exit $failed
