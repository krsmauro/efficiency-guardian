# Paso 5 del instalador: quitar de /etc/hosts las líneas manuales antiguas que
# bloquean dominios de las listas (hoy, 4 líneas de YouTube; ver docs/entorno.md).
# Si se quedan, "guardian stop" no desbloquearía esos sitios. Solo se quitan si
# el usuario responde que sí, y antes se guarda una copia.

# IPs con las que se suele bloquear a mano.
readonly LEGACY_IPS=(0.0.0.0 127.0.0.1 :: ::1)

install_migrate_hosts() {
  local current cleaned backup answer=

  blocklist_load $BLOCKLIST_DIR || die "las listas instaladas no son válidas"
  hosts_read $HOSTS_FILE
  current=$REPLY
  hosts_parse "$current" || die "$HOSTS_ERROR"
  legacy_filter "$current"
  cleaned=$REPLY

  if (( $#LEGACY_LINES == 0 )); then
    say "   No hay líneas manuales antiguas."
    return 0
  fi

  say "   Estas líneas de $HOSTS_FILE bloquean a mano sitios que ahora gestiona guardian:"
  print -rl -- "     "${^LEGACY_LINES}
  say "   Si se quedan, 'guardian stop' no desbloqueará esos sitios."
  read -r "answer?   ¿Quitarlas? [s/N] " < /dev/tty || true
  if [[ $answer != [sS]* ]]; then
    say "   Se dejan como están."
    return 0
  fi

  backup=$REAL_DATA_DIR/hosts.before-install.$(date +%Y%m%d-%H%M%S)
  ( umask 077; print -rn -- "$current" > $backup )
  hosts_write_atomic $HOSTS_FILE "$cleaned"
  dns_flush
  log_event "install: quitadas $#LEGACY_LINES líneas manuales antiguas"
  say "   Quitadas. Copia de seguridad: $backup"
}

# legacy_filter contenido
# Busca, FUERA del bloque gestionado, las líneas que solo bloquean dominios de
# BLOCKED_DOMAINS (por ejemplo "0.0.0.0 youtube.com"). Deja en:
#   LEGACY_LINES  esas líneas
#   REPLY         el contenido sin ellas; el resto queda byte a byte
legacy_filter() {
  local line inside=0
  local -a lines=("${(@ps:\n:)1}") kept=()
  typeset -ga LEGACY_LINES=()
  for line in "${lines[@]}"; do
    if [[ $line == "$BEGIN_MARK"* ]]; then inside=1; fi
    if (( ! inside )) && is_legacy_line "$line"; then
      LEGACY_LINES+=("$line")
    else
      kept+=("$line")
    fi
    if [[ $line == "$END_MARK"* ]]; then inside=0; fi
  done
  REPLY=${(pj:\n:)kept}
}

# is_legacy_line línea
# 0 si es "IP dominio [dominio...]" con una IP de bloqueo y TODOS los dominios
# en las listas. Si mezcla otros dominios, no se toca. Los comentarios no cuentan.
is_legacy_line() {
  local name
  local -a words=(${=1%%\#*})
  # Dos "if" separados a propósito: zsh expande $words[1] antes de evaluar el ||,
  # y con una línea vacía ese error haría que la condición fallara en silencio.
  if (( $#words < 2 )); then return 1; fi
  if (( ! ${LEGACY_IPS[(Ie)$words[1]]} )); then return 1; fi
  for name in "${(@)words[2,-1]}"; do
    if (( ! ${BLOCKED_DOMAINS[(Ie)${(L)name}]} )); then return 1; fi
  done
  return 0
}
