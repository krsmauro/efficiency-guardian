#!/bin/zsh -f
# Pruebas de lib/hosts-block.zsh: localizar, quitar y construir el bloque (solo texto).

source ${0:A:h}/assert.zsh
source $REPO/lib/log.zsh
source $REPO/lib/hosts-block.zsh

# Los marcadores se escriben aquí a mano, para no comprobar el módulo contra sí mismo.
begin='# >>> efficiency-guardian (gestionado automáticamente; no editar a mano) >>>'
end='# <<< efficiency-guardian <<<'

section "Formato del bloque"
hosts_with_block $'127.0.0.1\tlocalhost\n' youtube.com youtu.be
assert_eq "al final, tras una línea en blanco, 2 líneas por dominio" \
  $'127.0.0.1\tlocalhost\n\n'"$begin"$'\n0.0.0.0 youtube.com\n:: youtube.com\n0.0.0.0 youtu.be\n:: youtu.be\n'"$end"$'\n' \
  "$REPLY"

section "Sin bloque"
hosts_parse $'127.0.0.1\tlocalhost\n'
assert_eq "inactivo" 0 $HOSTS_ACTIVE
assert_eq "todo queda fuera del bloque" $'127.0.0.1\tlocalhost\n' "$HOSTS_OUTSIDE"

section "Ida y vuelta: poner y quitar el bloque"
for original in $'a\nb\n' $'a\n\n' '' $'\n' $'a\nb'; do
  name=${(qqqq)original}
  hosts_with_block "$original" youtube.com www.youtube.com
  built=$REPLY
  hosts_parse "$built"
  assert_eq "$name: activo" 1 $HOSTS_ACTIVE
  assert_eq "$name: cuenta 2 dominios" 2 $HOSTS_COUNT
  if [[ -z $original || $original == *$'\n' ]]; then expected=$original; else expected=$original$'\n'; fi
  assert_eq "$name: al quitarlo vuelve al original (caso 3 y 9)" "$expected" "$HOSTS_OUTSIDE"
  hosts_with_block "$HOSTS_OUTSIDE" youtube.com www.youtube.com
  assert_eq "$name: reconstruirlo da lo mismo (caso 2)" "$built" "$REPLY"
done

section "Contenido después del bloque (editado a mano)"
hosts_parse $'a\n\n'"$begin"$'\n0.0.0.0 x.com\n:: x.com\n'"$end"$'\nz\n'
assert_eq "se conserva fuera del bloque" $'a\nz\n' "$HOSTS_OUTSIDE"
assert_eq "cuenta 1 dominio" 1 $HOSTS_COUNT

section "Marcadores dañados (caso 5): error, para no tocar el archivo"
typeset -A broken=(
  "inicio sin fin"   $'a\n'"$begin"$'\n0.0.0.0 x.com\n'
  "fin sin inicio"   $'a\n'"$end"$'\n'
  "fin antes"        $'a\n'"$end"$'\n'"$begin"$'\n'
  "dos bloques"      "$begin"$'\n'"$end"$'\n'"$begin"$'\n'"$end"$'\n'
)
for name in ${(k)broken}; do
  HOSTS_ERROR=
  if hosts_parse "${broken[$name]}"; then st=0; else st=1; fi
  assert_eq "$name: error" 1 $st
  assert_contains "$name: lo explica" "marcadores" "$HOSTS_ERROR"
done

finish
