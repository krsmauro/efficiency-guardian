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

section "Varios grupos y otra duración"
new_case
set_config PASS_GROUPS youtube,twitch
set_config PASS_MINUTES 10
run_guardian start
run_guardian pass
assert_false "youtube.com desbloqueado" blocked youtube.com
assert_false "twitch.tv desbloqueado" blocked twitch.tv
assert_true "facebook.com sigue bloqueado" blocked facebook.com
assert_eq "dura 10 min" $(( T0 + 10 * 60 )) "$(state_value PASS_UNTIL)"

section "Una sesión nueva empieza con el contador a 0"
set_config STOP_DELAY_MINUTES 0
run_guardian stop
run_guardian start
assert_eq "contador a 0" 0 "$(state_value PASSES_USED)"

finish
