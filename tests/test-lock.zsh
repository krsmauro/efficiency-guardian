#!/bin/zsh -f
# Pruebas del candado (lib/lock.zsh): un comando que escribe espera a que
# termine el otro; status no espera. Tarda unos 4 segundos.

source ${0:A:h}/assert.zsh
source ${0:A:h}/e2e.zsh
zmodload zsh/datetime    # EPOCHREALTIME, para medir la espera

# hold_lock: otro proceso toma el candado durante 2 segundos. Vuelve cuando ya
# lo tiene (avisa creando un archivo), para no depender de un "sleep" fijo.
hold_lock() {
  local ready=$CASE/lock-ready tries=0
  rm -f $ready
  /bin/zsh -fc "zmodload zsh/system; zsystem flock -f fd $CASE/data/lock; : > $ready; sleep 2" &
  HOLDER=$!
  while [[ ! -e $ready ]] && (( tries++ < 100 )); do sleep 0.05; done
  assert_true "el otro proceso tiene el candado" test -e $ready
}

new_case
run_guardian start

section "Un comando que escribe espera su turno"
hold_lock
started=$EPOCHREALTIME
run_guardian stop
waited=$(( EPOCHREALTIME - started ))
assert_status "sale con 0" 0 $ST "$OUT"
assert_true "esperó a que se soltara el candado (${waited%.*} s)" test $(( waited >= 1 )) = 1
assert_false "y luego hizo su trabajo" test "$(state_value STOP_AT)" = 0
wait $HOLDER

section "status no usa el candado"
hold_lock
started=$EPOCHREALTIME
run_guardian status
waited=$(( EPOCHREALTIME - started ))
assert_status "sale con 0" 0 $ST "$OUT"
assert_true "no esperó" test $(( waited < 1 )) = 1
wait $HOLDER

finish
