#!/bin/zsh -f
# Pruebas de punta a punta de pass con otra configuración o con las listas
# dañadas. (El funcionamiento normal del pase está en test-pass.zsh.)

source ${0:A:h}/assert.zsh
source ${0:A:h}/e2e.zsh

section "Con las listas dañadas, el pase no se gasta"
new_case
run_guardian start
mkdir -p $T_TMP/lists-bad
cp $REPO/blocklists/*.txt $T_TMP/lists-bad/
print -r -- "mal dominio" >> $T_TMP/lists-bad/facebook.txt
CASE_LISTS=$T_TMP/lists-bad
run_guardian pass
assert_status "error" 1 $ST "$OUT"
assert_contains "lo explica" "no se gastó el pase" "$OUT"
assert_eq "no lo cuenta" 0 "$(state_value PASSES_USED)"
rm $T_TMP/lists-bad/youtube.txt
run_guardian pass
assert_contains "sin la lista del grupo, tampoco" "no existe el grupo" "$OUT"

section "PASS_MAX_PER_SESSION=0: ningún pase"
new_case
set_config PASS_MAX_PER_SESSION 0
run_guardian start
run_guardian pass
assert_status "error" 1 $ST "$OUT"

section "Varios grupos: cada pase desbloquea uno; sin elegir, el primero"
new_case
set_config PASS_GROUPS youtube,twitch
set_config PASS_MINUTES 10
run_guardian start
run_guardian pass
assert_false "youtube.com desbloqueado" blocked youtube.com
assert_true "twitch.tv sigue bloqueado" blocked twitch.tv
assert_eq "dura 10 min" $(( T0 + 10 * 60 )) "$(state_value PASS_UNTIL)"
at_minute 10
run_guardian pass twitch
assert_status "pass twitch sale con 0" 0 $ST "$OUT"
assert_contains "lo dice" "twitch desbloqueado hasta las 08:20. Te quedan 1 de 3." "$OUT"
assert_false "twitch.tv desbloqueado" blocked twitch.tv
assert_true "youtube.com bloqueado otra vez" blocked youtube.com
assert_true "facebook.com sigue bloqueado" blocked facebook.com
assert_eq "anota el grupo" twitch "$(state_value PASS_GROUP)"

section "Un grupo fuera de PASS_GROUPS no tiene pase"
at_minute 20
run_guardian pass facebook
assert_status "error" 1 $ST "$OUT"
assert_contains "dice cuáles sí" "facebook no tiene pases (PASS_GROUPS: youtube, twitch)" "$OUT"
assert_eq "no lo cuenta" 2 "$(state_value PASSES_USED)"

section "Estado de antes de la Fase 6 con un pase en curso (sin PASS_GROUP): el primer grupo"
new_case
mkdir -p $CASE/data
print -rl -- SESSION=indefinite SESSION_STARTED=$T0 BOOT_ID=boot1 PASSES_USED=1 \
  PASS_UNTIL=$(( T0 + 5 * 60 )) > $CASE/data/state
run_guardian reconcile
assert_eq "PASS_GROUP=youtube" youtube "$(state_value PASS_GROUP)"
assert_false "youtube.com sigue desbloqueado" blocked youtube.com
assert_true "facebook.com bloqueado" blocked facebook.com

section "Una sesión nueva empieza con el contador a 0"
set_config STOP_DELAY_MINUTES 0
run_guardian stop
run_guardian start
assert_eq "contador a 0" 0 "$(state_value PASSES_USED)"

finish
