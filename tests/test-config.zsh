#!/bin/zsh -f
# Pruebas de lib/config.zsh y lib/config-check.zsh: leer y validar la configuración sin ejecutarla.

source ${0:A:h}/assert.zsh
source $REPO/lib/log.zsh
source $REPO/lib/config.zsh
source $REPO/lib/config-check.zsh

lists=$REPO/blocklists
conf=$T_TMP/config

# load: carga la configuración en un subproceso; deja la salida en OUT y el código en ST.
load() {
  OUT=$(config_load $conf 2>&1)
  ST=$?
}

section "config.default coincide con los valores por defecto del código"
config_load $REPO/config.default
for key in ${(ko)CONFIG_DEFAULTS}; do
  assert_eq "$key" "$CONFIG_DEFAULTS[$key]" "$CFG[$key]"
  assert_true "$key aparece en config.default" grep -q "^$key=" $REPO/config.default
done

section "Sin archivo: valores por defecto"
rm -f $conf
config_load $conf
assert_eq "duraciones" "25 50 90" "$CFG_PRESETS"
assert_eq "grupos con pase" "youtube" "$CFG_PASS_GROUPS"
assert_eq "retraso" 5 "$CFG[STOP_DELAY_MINUTES]"

section "Valores válidos, comentarios y fines de línea de Windows"
print -rn -- $'# comentario\n\n   # sangrado\nTIMED_PRESETS=10,25,10\r\nTIMED_LOCK=yes\n'\
$'STOP_DELAY_MINUTES=0\nPASS_GROUPS=youtube,twitch\nPASS_MAX_PER_SESSION=0  \nAUTOSTART_AT_BOOT=no' > $conf
config_load $conf
assert_eq "duraciones, sin repetidas" "10 25" "$CFG_PRESETS"
assert_eq "candado" yes "$CFG[TIMED_LOCK]"
assert_eq "retraso 0" 0 "$CFG[STOP_DELAY_MINUTES]"
assert_eq "dos grupos" "youtube twitch" "$CFG_PASS_GROUPS"
assert_eq "sin pases" 0 "$CFG[PASS_MAX_PER_SESSION]"
assert_eq "sin arranque automático (última línea sin salto)" no "$CFG[AUTOSTART_AT_BOOT]"
assert_eq "lo que falta, por defecto" 5 "$CFG[PASS_MINUTES]"

section "Valores inválidos: error"
for line in 'PASS_MINUTES=abc' 'PASS_MINUTES=0' 'PASS_MINUTES=61' 'PASS_MINUTES=' \
            'STOP_DELAY_MINUTES=-1' 'STOP_DELAY_MINUTES=05' 'STOP_DELAY_MINUTES=99999' \
            'PASS_MAX_PER_SESSION=21' 'TIMED_LOCK=si' 'AUTOSTART_AT_BOOT=YES' \
            'TIMED_PRESETS=' 'TIMED_PRESETS=0' 'TIMED_PRESETS=481' 'TIMED_PRESETS=25,abc' \
            'PASS_GROUPS=' 'PASS_GROUPS=Youtube' 'PASS_GROUPS=you_tube' 'PASS_GROUPS=youtube,../x' \
            'COSA=1' 'pass_minutes=5' 'PASS_MINUTES = 5' 'PASS_MINUTES=5 # comentario' 'PASS_MINUTES'; do
  print -r -- "$line" > $conf
  load
  assert_status "rechaza ${(qq)line}" 1 $ST "$OUT"
done

section "Nada se ejecuta"
for line in "STOP_DELAY_MINUTES=\$(touch $T_TMP/pwned)" "PASS_MINUTES=\`touch $T_TMP/pwned\`" \
            "PASS_MINUTES=a[\$(touch $T_TMP/pwned)]" "PASS_GROUPS=youtube;touch $T_TMP/pwned"; do
  print -r -- "$line" > $conf
  load
  assert_status "rechaza ${(qq)line}" 1 $ST "$OUT"
done
assert_false "no se creó ningún archivo" test -e $T_TMP/pwned

section "Que los grupos existan se comprueba aparte (instalador y pass)"
print -r -- "PASS_GROUPS=youtube,noexiste" > $conf
config_load $conf
assert_eq "config_load lo acepta: borrar una lista no debe bloquear stop" "youtube noexiste" "$CFG_PASS_GROUPS"
OUT=$(config_check_pass_groups $lists 2>&1)
assert_status "config_check_pass_groups lo rechaza" 1 $? "$OUT"
assert_contains "dice cuál falta" "no existe el grupo 'noexiste'" "$OUT"
print -r -- "PASS_GROUPS=youtube,twitch" > $conf
config_load $conf
assert_true "con grupos que existen, pasa" config_check_pass_groups $lists

section "Clave repetida"
print -rl -- PASS_MINUTES=5 PASS_MINUTES=10 > $conf
load
assert_status "error" 1 $ST "$OUT"
assert_contains "lo explica" "config:2: PASS_MINUTES está repetida" "$OUT"

section "Muestra todos los errores, con su línea"
print -rl -- 'PASS_MINUTES=abc' 'COSA=1' > $conf
load
assert_contains "el valor inválido" "PASS_MINUTES" "$OUT"
assert_contains "la clave desconocida, con su línea" "config:2: clave desconocida: COSA" "$OUT"

finish
