#!/bin/zsh -f
# Pruebas de lib/blocklist.zsh: leer, normalizar y validar las listas de dominios.

source ${0:A:h}/assert.zsh
source $REPO/lib/log.zsh
source $REPO/lib/blocklist.zsh

lists=$T_TMP/lists
mkdir $lists

# write_list grupo contenido   (sin salto de línea añadido: el contenido manda)
write_list() {
  print -rn -- "$2" > $lists/$1.txt
}

reset_lists() {
  rm -f -- $lists/*(N)
}

# load: carga las listas en un subproceso; deja la salida en OUT y el código en ST.
load() {
  OUT=$(blocklist_load $lists 2>&1)
  ST=$?
}

section "Normalización (caso 8)"
write_list a $'# comentario\n\nYouTube.COM\r\nyoutube.com  \n\twww.youtube.com # al final\nyoutu.be'
write_list b $'youtube.com\nfacebook.com\n'
blocklist_load $lists
assert_eq "comentarios, vacías, mayúsculas, espacios y duplicados" \
  "youtube.com www.youtube.com youtu.be facebook.com" "${BLOCKED_DOMAINS[*]}"
assert_eq "grupos en orden alfabético" "a b" "${BLOCKED_GROUPS[*]}"

section "Dominios inválidos (caso 6)"
for bad in 'you tube.com' '*.youtube.com' 'youtube' '-youtube.com' 'youtube..com' \
           'youtube.com/watch' 'http://youtube.com' 'youtube.com.' 'yóutube.com'; do
  reset_lists
  write_list a $'youtube.com\n'"$bad"$'\n'
  load
  assert_status "rechaza ${(qq)bad}" 1 $ST "$OUT"
  assert_contains "dice archivo y línea de ${(qq)bad}" "a.txt:2" "$OUT"
done

section "Dominios que nunca se bloquean (caso 7)"
for forbidden in accounts.youtube.com ACCOUNTS.YouTube.com studio.youtube.com upload.youtube.com \
                 youtube.googleapis.com t.co linkedin.com www.linkedin.com lnkd.in; do
  reset_lists
  write_list a "youtube.com"$'\n'"$forbidden"
  load
  assert_status "se niega a bloquear $forbidden" 1 $ST "$OUT"
done
assert_contains "explica el motivo" "nunca se bloquea" "$OUT"

section "Grupos omitidos (los de un pase en curso)"
reset_lists
write_list a $'youtube.com\ncompartido.com\n'
write_list b $'facebook.com\ncompartido.com\n'
blocklist_load $lists a
assert_eq "solo los dominios de b; el compartido sigue bloqueado" "facebook.com compartido.com" "${BLOCKED_DOMAINS[*]}"
blocklist_load $lists a b
assert_eq "omitirlos todos deja la lista vacía, sin error" 0 $#BLOCKED_DOMAINS
write_list a $'you tube.com\n'
OUT=$(blocklist_load $lists a 2>&1)
assert_status "un grupo omitido se valida igual" 1 $? "$OUT"

section "Listas que faltan o están vacías"
reset_lists
load
assert_status "carpeta sin listas: error" 1 $ST "$OUT"
write_list a $'# solo comentarios\n\n'
load
assert_status "listas sin dominios: error" 1 $ST "$OUT"
reset_lists
write_list 'Mi Grupo' 'youtube.com'
load
assert_status "nombre de grupo raro: error" 1 $ST "$OUT"

section "Las listas del repositorio son válidas"
blocklist_load $REPO/blocklists
assert_eq "los 10 grupos de D6" "facebook instagram pinterest reddit threads tiktok twitch whatsapp x youtube" \
  "${BLOCKED_GROUPS[*]}"
assert_eq "82 dominios" 82 $#BLOCKED_DOMAINS

finish
