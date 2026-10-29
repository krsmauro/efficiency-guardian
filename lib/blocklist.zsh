# Listas de dominios a bloquear: leer, normalizar y validar.
#
# Cada grupo es un archivo <grupo>.txt con un dominio por línea. Se ignoran las
# líneas vacías y los comentarios (#), se pasa a minúsculas y se quitan los
# duplicados. Si un solo dominio es inválido o está en la lista "nunca bloquear",
# no se carga nada: mejor no bloquear que bloquear algo que no toca.

# Dominios que nunca se bloquean, aunque aparezcan en una lista.
# Motivos en docs/investigacion/04-dominios.md.
readonly -a NEVER_BLOCK=(
  accounts.youtube.com      # el inicio de sesión de Google pasa por aquí
  youtube.googleapis.com    # reproductor de videos de Google Drive
  studio.youtube.com        # YouTube Studio (D6b)
  upload.youtube.com        # YouTube Studio (D6b)
  t.co                      # enlaces acortados en correos y newsletters
  linkedin.com              # LinkedIn se conserva
  www.linkedin.com
  lnkd.in
)

readonly DOMAIN_REGEX='^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$'
readonly GROUP_REGEX='^[a-z0-9-]+$'

# blocklist_load carpeta
# Lee todos los <grupo>.txt de la carpeta (en orden alfabético) y deja en:
#   BLOCKED_DOMAINS  los dominios, sin duplicados, en el orden en que aparecen
#   BLOCKED_GROUPS   los nombres de los grupos
# Si algo está mal, muestra TODOS los errores y devuelve 1.
blocklist_load() {
  local dir=$1 file group line_number line errors=0
  local -a files=($dir/*.txt(N)) words
  local -A seen=()
  typeset -ga BLOCKED_DOMAINS=() BLOCKED_GROUPS=()

  if (( $#files == 0 )); then
    err "no hay listas (*.txt) en $dir"
    return 1
  fi

  for file in $files; do
    group=${file:t:r}
    if [[ ! $group =~ $GROUP_REGEX ]]; then
      err "${file:t}: nombre de grupo inválido (solo minúsculas, números y guiones)"
      errors=1
      continue
    fi
    BLOCKED_GROUPS+=$group
    line_number=0
    while IFS= read -r line || [[ -n $line ]]; do
      line_number=$(( line_number + 1 ))
      line=${line%%\#*}              # quitar el comentario
      words=(${=line//$'\r'/})       # separar por espacios (y quitar \r de Windows)
      if (( $#words == 0 )); then continue; fi
      if ! blocklist_check "${file:t}:$line_number" "${(j: :)words}"; then
        errors=1
        continue
      fi
      if (( ! ${+seen[${(L)words[1]}]} )); then
        seen[${(L)words[1]}]=1
        BLOCKED_DOMAINS+=${(L)words[1]}
      fi
    done < $file
  done

  if (( errors )); then return 1; fi
  if (( $#BLOCKED_DOMAINS == 0 )); then
    err "las listas de $dir no tienen ningún dominio"
    return 1
  fi
  return 0
}

# blocklist_check "archivo:línea" dominio
# Devuelve 1 (con un mensaje) si el dominio es inválido o no se debe bloquear.
blocklist_check() {
  local where=$1 domain=${(L)2}
  if [[ ! $domain =~ $DOMAIN_REGEX ]]; then
    err "$where: dominio inválido: ${(qq)2} (sin espacios, comodines, rutas ni http://)"
    return 1
  fi
  if (( ${NEVER_BLOCK[(Ie)$domain]} )); then
    err "$where: $domain nunca se bloquea (ver docs/investigacion/04-dominios.md)"
    return 1
  fi
  return 0
}
