#!/bin/zsh -f
# Prueba de permisos de la Fase 3 (paso 3.1). La ejecuta el usuario, SIN sudo.
#
# Pregunta: ¿macOS deja que close-tabs controle los navegadores desde la
# terminal y desde un LaunchAgent (en segundo plano, como quedará instalado)?
# ¿Ve las ventanas privadas?
#
# No toca /etc/hosts: usa un hosts temporal que "bloquea" solo example.com.
# Antes, en cada navegador que uses, abre:
#   - https://example.com en una pestaña normal y en una ventana privada: se deben cerrar.
#   - https://example.org: se debe quedar abierta.
#
# Uso:
#   zsh tools/try-close-tabs.zsh terminal   # A: desde esta terminal
#   zsh tools/try-close-tabs.zsh agent      # B: desde un LaunchAgent temporal
#
# Si macOS pregunta "¿Permitir que X controle Brave?", anota QUIÉN lo pide (X) y
# pulsa Permitir. Se puede quitar después en Ajustes del Sistema → Privacidad y
# seguridad → Automatización.

emulate -R zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

readonly REPO=${0:A:h:h}
readonly LABEL=com.efficiency-guardian.try-close-tabs
readonly WAIT_SECONDS=180   # da tiempo a responder los avisos de permisos

if (( EUID == 0 )); then print -ru2 -- "Sin sudo: la prueba es sobre los permisos del usuario."; exit 1; fi
if [[ ${1:-} != (terminal|agent) ]]; then
  print -ru2 -- "Uso: zsh tools/try-close-tabs.zsh terminal|agent"
  exit 2
fi

# Copia close-tabs y su módulo a una carpeta temporal, con la misma forma que la
# instalación (close-tabs/ junto a lib/). Para el LaunchAgent importa: macOS
# protege ~/Documents y, en segundo plano, leer el repositorio podría fallar por
# eso y confundir la prueba.
tmp=$(mktemp -d "${TMPDIR:-/tmp}/guardian-try.XXXXXX")
trap 'launchctl bootout gui/$UID/$LABEL 2>/dev/null || true; rm -rf -- $tmp' EXIT
mkdir -p $tmp/close-tabs $tmp/lib
cp -p $REPO/close-tabs/{close-tabs.zsh,match.js,browser.js,run.js} $tmp/close-tabs/
cp -p $REPO/lib/hosts-block.zsh $tmp/lib/

# El hosts de prueba, con el formato real del motor.
source $REPO/lib/hosts-block.zsh
hosts_with_block $'127.0.0.1\tlocalhost\n' example.com www.example.com
print -rn -- "$REPLY" > $tmp/hosts

if [[ $1 == terminal ]]; then
  print -r -- "A. Ejecutando close-tabs desde esta terminal…"
  GUARDIAN_HOSTS_FILE=$tmp/hosts $tmp/close-tabs/close-tabs.zsh && st=0 || st=$?
  print -r -- "Código de salida: $st (0 = sin errores)"
  exit 0
fi

# B. Un LaunchAgent que ejecuta close-tabs una sola vez. El plist queda en la
# carpeta temporal (no en ~/Library/LaunchAgents), así no se queda registrado.
cat > $tmp/$LABEL.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$tmp/close-tabs/close-tabs.zsh</string></array>
  <key>EnvironmentVariables</key><dict><key>GUARDIAN_HOSTS_FILE</key><string>$tmp/hosts</string></dict>
  <key>StandardOutPath</key><string>$tmp/agent.log</string>
  <key>StandardErrorPath</key><string>$tmp/agent.log</string>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
EOF
plutil -lint -s $tmp/$LABEL.plist
launchctl bootout gui/$UID/$LABEL 2>/dev/null || true   # por si quedó de una prueba anterior
launchctl bootstrap gui/$UID $tmp/$LABEL.plist
print -r -- "B. LaunchAgent cargado. Esperando a que termine (máximo $WAIT_SECONDS s)…"

info=
for (( i = 0; i < WAIT_SECONDS; i++ )); do
  info=$(launchctl print gui/$UID/$LABEL 2>/dev/null || true)
  if [[ $info == *'runs = '<1->* && $info == *'state = not running'* ]]; then break; fi
  sleep 1
done
print -r -- "--- Lo que escribió close-tabs:"
if [[ -s $tmp/agent.log ]]; then cat $tmp/agent.log; else print -r -- "(nada: 0 pestañas cerradas y sin errores)"; fi
print -r -- "--- Lo que dice launchd:"
print -rl -- ${(M)${(f)info}:#$'\t'(state|runs|last exit code) =*}   # solo el primer nivel
