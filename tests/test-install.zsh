#!/bin/zsh -f
# Pruebas de las partes del instalador que no necesitan root: la migración de
# las líneas manuales antiguas, el plist del LaunchDaemon, la comprobación de
# permisos y que las rutas coincidan con las del motor. La regla de sudoers,
# en test-sudoers.zsh.

source ${0:A:h}/assert.zsh
for file in lib/env.zsh lib/log.zsh lib/config.zsh lib/config-check.zsh lib/blocklist.zsh \
            lib/hosts-block.zsh lib/hosts-write.zsh \
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

section "Plist del LaunchDaemon"
plist=$REPO/launchd/$DAEMON_LABEL.plist
assert_true "es un plist válido" plutil -lint -s $plist
assert_eq "Label" $DAEMON_LABEL "$(plutil -extract Label raw -o - $plist)"
assert_eq "ejecuta el motor instalado" $ENGINE "$(plutil -extract ProgramArguments.0 raw -o - $plist)"
assert_eq "con reconcile" reconcile "$(plutil -extract ProgramArguments.1 raw -o - $plist)"
assert_eq "y nada más" 2 "$(plutil -extract ProgramArguments raw -o - $plist)"
assert_eq "cada 30 s" 30 "$(plutil -extract StartInterval raw -o - $plist)"
assert_eq "y al cargarse (al arrancar el Mac)" true "$(plutil -extract RunAtLoad raw -o - $plist)"

section "Comprobación de permisos (paso 5)"
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
assert_eq "configuración (lib/env.zsh)" "$CONFIG_INSTALLED" "$REAL_CONFIG_FILE"
assert_eq "configuración y listas (bin/guardian)" "$ETC_DIR" "$(sed -n 's/^readonly INSTALLED_ETC=//p' $REPO/bin/guardian)"

finish
