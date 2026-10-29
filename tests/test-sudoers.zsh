#!/bin/zsh -f
# Pruebas de la regla de sudoers (install/sudoers.zsh). visudo solo comprueba
# la sintaxis: qué admite la regla se prueba con sudo_allows, que imita cómo
# compara sudo (man sudoers; match_command.c y toke.l, leídos el 2026-10-29).

source ${0:A:h}/assert.zsh
for file in lib/env.zsh lib/log.zsh lib/config.zsh lib/config-check.zsh lib/blocklist.zsh \
            install/paths.zsh install/sudoers.zsh; do
  source $REPO/$file
done

# sudo_allows regla argumentos... → 0 si alguna entrada admite esos argumentos.
# Los del usuario se unen con espacios. Los de una entrada son todo lo que va
# tras la ruta: sin nada, cualquiera; "" solo, ninguno; si empiezan con ^ y
# terminan con $, un patrón ERE (regexec, como =~); si no, texto exacto.
sudo_allows() {
  local rule=$1 entry args wanted
  shift
  wanted="$*"
  for entry in "${(@s:, :)${rule#*NOPASSWD: }}"; do
    if [[ $entry == $ENGINE ]]; then return 0; fi
    if [[ $entry != "$ENGINE "* ]]; then continue; fi
    args=${entry#"$ENGINE "}
    if [[ $args == '""' ]]; then
      if [[ -z $wanted ]]; then return 0; fi
    elif [[ $args[1] == '^' && $args[-1] == '$' ]]; then
      if [[ $wanted =~ $args ]]; then return 0; fi
    elif [[ $wanted == "$args" ]]; then
      return 0
    fi
  done
  return 1
}

section "La regla"
g=$ENGINE m='[1-9][0-9]?[0-9]?$'
rule=$(sudoers_rule mauro | grep -v '^#')
assert_eq "texto exacto para los comandos sin más, y patrones que empiezan con el subcomando" \
  "mauro ALL=(root) NOPASSWD: $g start, $g ^start $m, $g stop, $g cancel-stop, $g pass, \
$g ^pass [a-z0-9-]+\$, $g extend, $g ^extend $m, $g ^shorten $m" "$rule"
sudoers_rule mauro > $T_TMP/sudoers
assert_true "visudo la acepta" visudo -c -q -f $T_TMP/sudoers
for entry in "${(@s:, :)${rule#*NOPASSWD: }}"; do
  if [[ $entry != "$g ^"* ]]; then assert_false "${(qq)entry}: sin comodines de sudo" eval '[[ $entry == *[*?\[]* ]]'; fi
done

section "Lo que manda la app pasa sin contraseña (el motor rechaza lo que no esté en la configuración)"
for args in start 'start 25' 'start 999' stop cancel-stop pass 'pass youtube' 'pass social-media' \
            extend 'extend 90' 'shorten 25'; do
  assert_true "${(qq)args}" sudo_allows "$rule" ${=args}
done

section "Lo demás pide contraseña"
for args in '' 'stop ahora' 'start 25 50' 'start 025' 'start 0' 'start 1000' 'start abc' start25 \
            'pass YouTube' 'pass a b' 'pass ../x' 'extend x' shorten 'cancel-stop x' status \
            'status --json' reconcile; do
  assert_false "${(qq)args}" sudo_allows "$rule" ${=args}
done

section "Los fallos de la primera versión (instalada el 2026-10-29), que el Mac rechazó"
assert_false "un patrón que no va primero se lee como texto" \
  sudo_allows "x NOPASSWD: $g start ^$m" start 25
assert_false "\"\" tras el subcomando no significa 'sin argumentos'" sudo_allows "x NOPASSWD: $g start \"\"" start

section "Los mismos patrones con los que valida el motor"
for arg in 1 25 90 480 999; do assert_true "minutos: ${(qq)arg} pasa" eval '[[ $arg =~ $MINUTES_REGEX ]]'; done
for arg in 0 025 1000 -5 2a '25 50' ''; do assert_false "minutos: ${(qq)arg} no pasa" eval '[[ $arg =~ $MINUTES_REGEX ]]'; done
for arg in youtube social-media x1; do assert_true "grupo: ${(qq)arg} pasa" eval '[[ $arg =~ $GROUP_REGEX ]]'; done
for arg in YouTube ../x 'a b' a,b ''; do assert_false "grupo: ${(qq)arg} no pasa" eval '[[ $arg =~ $GROUP_REGEX ]]'; done

section "No depende de la configuración"
print -rl -- "TIMED_PRESETS=15,120" "PASS_GROUPS=youtube,reddit" > $T_TMP/config
config_load $T_TMP/config
assert_eq "otra configuración, la misma regla" "$(cat $T_TMP/sudoers)" "$(sudoers_rule mauro)"

finish
