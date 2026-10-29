#!/bin/zsh -f
# Pruebas de lib/state.zsh: leer, validar y escribir el estado de forma atómica.

source ${0:A:h}/assert.zsh
GUARDIAN_DATA_DIR=$T_TMP/data
for module in env log clock hosts-write state; do source $REPO/lib/$module.zsh; done
file=$T_TMP/data/state

section "Sin archivo (primera vez)"
state_load
assert_eq "no existía" 0 $STATE_EXISTS
assert_eq "sin sesión" none "$S[SESSION]"
assert_eq "contador a 0" 0 "$S[PASSES_USED]"

section "Guardar y volver a leer"
S[SESSION]=timed S[SESSION_STARTED]=100 S[SESSION_ENDS]=1600 S[BOOT_ID]=ABC-123
S[STOP_AT]=400 S[PASSES_USED]=2 S[PASS_UNTIL]=300
state_save
assert_eq "formato: una clave por línea, siempre en el mismo orden" \
  $'SESSION=timed\nSESSION_STARTED=100\nSESSION_ENDS=1600\nBOOT_ID=ABC-123\nSTOP_AT=400\nPASSES_USED=2\nPASS_UNTIL=300' \
  "$(cat $file)"
assert_eq "legible por todos (644)" 644 "$(mode_of $file)"
assert_eq "la carpeta también (755)" 755 "$(mode_of $T_TMP/data)"
assert_eq "sin temporales olvidados" "" "$(print -r -- $T_TMP/data/.state.*(N))"
state_serialize
saved=$REPLY
state_load
assert_eq "existía" 1 $STATE_EXISTS
state_serialize
assert_eq "lee lo mismo que escribió" "$saved" "$REPLY"

section "Sin cambios, no reescribe"
inode=$(inode_of $file)
state_save
assert_eq "mismo inodo" "$inode" "$(inode_of $file)"

section "Con cambios, escritura atómica"
S[PASSES_USED]=3
state_save
assert_false "archivo nuevo (otro inodo)" test "$inode" = "$(inode_of $file)"
assert_eq "con el cambio" 3 "$(sed -n 's/^PASSES_USED=//p' $file)"

section "Claves que faltan: valor por defecto"
print -r -- "SESSION=indefinite" > $file
state_load
assert_eq "válido" 1 $STATE_EXISTS
assert_eq "la que está" indefinite "$S[SESSION]"
assert_eq "las que faltan" "0 0" "$S[STOP_AT] $S[PASS_UNTIL]"

section "Estado dañado: aviso, y se empieza de nuevo sin ejecutar nada"
for bad in 'SESSION=otra' 'STOP_AT=abc' 'STOP_AT=-1' 'STOP_AT=01' 'PASSES_USED=1 2' \
           "STOP_AT=\$(touch $T_TMP/pwned)" "STOP_AT=a[\$(touch $T_TMP/pwned)]" \
           'BOOT_ID=a b' 'BOOT_ID=' 'COSA=1' 'sin igual'; do
  print -rl -- 'SESSION=indefinite' "$bad" > $file
  OUT=$(state_load 2>&1)
  assert_contains "avisa con ${(qq)bad}" "estado dañado" "$OUT"
  state_load 2> /dev/null
  assert_eq "con ${(qq)bad}: como si no existiera" "0 none" "$STATE_EXISTS $S[SESSION]"
done
print -rn -- $'SESSION=indefinite\nSTOP_AT=0\0x\n' > $file
state_load 2> $T_TMP/nul.err
assert_contains "con un byte nulo: avisa" "byte nulo" "$(cat $T_TMP/nul.err)"
assert_eq "con un byte nulo: como si no existiera" "0 none" "$STATE_EXISTS $S[SESSION]"
assert_false "no se creó ningún archivo" test -e $T_TMP/pwned

finish
