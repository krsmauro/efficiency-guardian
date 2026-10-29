#!/bin/zsh -f
# Pruebas de las partes del instalador que no necesitan root: la migración de
# las líneas manuales antiguas, la regla de sudoers, la comprobación de
# permisos y que las rutas coincidan con las del motor.

source ${0:A:h}/assert.zsh
for file in lib/env.zsh lib/log.zsh lib/blocklist.zsh lib/hosts-block.zsh lib/hosts-write.zsh \
            install/paths.zsh install/verify.zsh install/migrate-hosts.zsh install/sudoers.zsh; do
  source $REPO/$file
done
blocklist_load $REPO/blocklists

section "Líneas manuales antiguas de esta Mac (docs/entorno.md)"
hosts_read $REPO/tests/fixtures/hosts
legacy_filter "$REPLY"
assert_eq "encuentra las 4 de YouTube" \
  $'0.0.0.0 youtube.com\n0.0.0.0 www.youtube.com\n0.0.0.0 m.youtube.com\n0.0.0.0 youtu.be' \
  "${(pj:\n:)LEGACY_LINES}"
assert_eq "conserva el resto byte a byte" "$(head -n 9 $REPO/tests/fixtures/hosts)"$'\n' "$REPLY"

section "Qué no se toca"
for line in '127.0.0.1 localhost' '::1 localhost' '255.255.255.255 broadcasthost' \
            '# 0.0.0.0 youtube.com' '0.0.0.0 youtube.com ejemplo.com' '10.0.0.5 youtube.com' \
            '0.0.0.0 accounts.youtube.com' '0.0.0.0'; do
  legacy_filter "$line"$'\n'
  assert_eq "no toca ${(qq)line}" 0 $#LEGACY_LINES
done

section "Qué sí se quita"
for line in '127.0.0.1 youtube.com' ':: www.youtube.com' '0.0.0.0   YouTube.com  # mío' \
            $'0.0.0.0\tyoutu.be m.youtube.com'; do
  legacy_filter $'a\n'"$line"$'\nb\n'
  assert_eq "quita ${(qq)line}" 1 $#LEGACY_LINES
  assert_eq "y deja lo demás" $'a\nb\n' "$REPLY"
done

section "El bloque gestionado no se toca"
hosts_with_block $'a\n' youtube.com www.youtube.com
legacy_filter "$REPLY"
assert_eq "ninguna línea del bloque cuenta como antigua" 0 $#LEGACY_LINES

section "Regla de sudoers"
assert_eq "solo start y stop, con argumentos exactos" \
  "mauro ALL=(root) NOPASSWD: /usr/local/sbin/guardian start, /usr/local/sbin/guardian stop" \
  "$(sudoers_rule mauro | grep -v '^#')"
sudoers_rule mauro > $T_TMP/sudoers
assert_true "visudo la acepta" visudo -c -q -f $T_TMP/sudoers

section "Comprobación de permisos (paso 4)"
touch $T_TMP/mine
ln -s /usr/bin/true $T_TMP/link
assert_true "un archivo del sistema es seguro" is_root_only /usr/bin/true
assert_false "un archivo del usuario no lo es" is_root_only $T_TMP/mine
assert_false "un enlace no lo es, aunque apunte a root" is_root_only $T_TMP/link
assert_false "una carpeta que todos pueden escribir no lo es" is_root_only /private/tmp
assert_false "lo que no existe no lo es" is_root_only $T_TMP/no-existe

section "Las rutas coinciden con las del motor"
assert_eq "módulos (bin/guardian)" "$LIB_DIR" "$(sed -n 's/^readonly INSTALLED_LIB=//p' $REPO/bin/guardian)"
assert_eq "listas (lib/env.zsh)" "$LISTS_DIR" "$REAL_BLOCKLIST_DIR"

finish
