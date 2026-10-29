# El bloque gestionado dentro de /etc/hosts: localizarlo, quitarlo y construirlo.
# Solo trabaja con texto (no lee ni escribe archivos), así se prueba fácil.
#
# Formato, siempre al final del archivo:
#
#   (línea en blanco)
#   # >>> efficiency-guardian (gestionado automáticamente; no editar a mano) >>>
#   0.0.0.0 youtube.com
#   :: youtube.com
#   # <<< efficiency-guardian <<<
#
# Dos líneas por dominio: 0.0.0.0 bloquea IPv4 y :: bloquea IPv6 (D1).
# Todo lo que está fuera del bloque se conserva byte a byte.

readonly BEGIN_MARK='# >>> efficiency-guardian'
readonly END_MARK='# <<< efficiency-guardian'
readonly BEGIN_LINE="$BEGIN_MARK (gestionado automáticamente; no editar a mano) >>>"
readonly END_LINE="$END_MARK <<<"

# hosts_parse contenido
# Deja en:
#   HOSTS_OUTSIDE  lo que está fuera del bloque, sin la línea en blanco que lo precede
#   HOSTS_ACTIVE   1 si hay bloque, 0 si no
#   HOSTS_COUNT    cuántos dominios tiene el bloque
# Si los marcadores están dañados (inicio sin fin, dos bloques...) devuelve 1 con
# el motivo en HOSTS_ERROR: en ese caso no hay que tocar el archivo.
hosts_parse() {
  local content=$1 i begin=0 end=0 begins=0 ends=0
  local -a lines=("${(@ps:\n:)content}") before after
  HOSTS_OUTSIDE=$content HOSTS_ACTIVE=0 HOSTS_COUNT=0 HOSTS_ERROR=

  for (( i = 1; i <= $#lines; i++ )); do
    if [[ $lines[i] == "$BEGIN_MARK"* ]]; then begin=$i; begins=$(( begins + 1 )); fi
    if [[ $lines[i] == "$END_MARK"* ]]; then end=$i; ends=$(( ends + 1 )); fi
  done

  if (( begins == 0 && ends == 0 )); then return 0; fi
  if (( begins != 1 || ends != 1 || begin > end )); then
    HOSTS_ERROR="marcadores de efficiency-guardian dañados en hosts (inicios: $begins, finales: $ends)."
    HOSTS_ERROR+=" No se tocó nada. Revisa el archivo a mano."
    return 1
  fi

  for (( i = begin + 1; i < end; i++ )); do
    if [[ $lines[i] == '0.0.0.0 '* ]]; then HOSTS_COUNT=$(( HOSTS_COUNT + 1 )); fi
  done

  # Cada línea de "before" iba seguida de un salto de línea; "after" conserva el suyo.
  before=("${(@)lines[1,begin-1]}")
  after=("${(@)lines[end+1,-1]}")
  if (( $#before )) && [[ -z $before[-1] ]]; then before[-1]=(); fi   # la línea en blanco separadora
  HOSTS_OUTSIDE=${(pj:\n:)before}
  if (( $#before )); then HOSTS_OUTSIDE+=$'\n'; fi
  HOSTS_OUTSIDE+=${(pj:\n:)after}
  HOSTS_ACTIVE=1
  return 0
}

# hosts_with_block contenido_sin_bloque dominio...
# Deja en REPLY el contenido con el bloque al final. Si el contenido no terminaba
# en salto de línea, se lo añade para que su última línea no se pegue al bloque.
hosts_with_block() {
  local outside=$1 domain
  shift
  REPLY=$outside
  if [[ -n $outside && $outside != *$'\n' ]]; then REPLY+=$'\n'; fi
  REPLY+=$'\n'"$BEGIN_LINE"$'\n'
  for domain in "$@"; do
    REPLY+="0.0.0.0 $domain"$'\n'":: $domain"$'\n'
  done
  REPLY+="$END_LINE"$'\n'
}
