#!/bin/zsh -f
# Ejecuta todas las pruebas (tests/test-*.zsh) y la regla de tamaño (check-length.zsh).
# No necesita root ni dependencias. Sale con 1 si algo falla.
#
# Uso: zsh tests/run.zsh

emulate -R zsh
setopt NO_UNSET PIPE_FAIL
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

here=${0:A:h}
failed=()

for test_file in $here/test-*.zsh; do
  print -r -- "== ${test_file:t}"
  if ! /bin/zsh -f $test_file; then failed+=${test_file:t}; fi
done

print -r -- "== check-length.zsh"
if ! /bin/zsh -f $here/check-length.zsh ${here:h}; then failed+=check-length.zsh; fi

print
if (( $#failed )); then
  print -r -- "RESULTADO: fallan ${failed[*]}"
  exit 1
fi
print -r -- "RESULTADO: todo bien"
