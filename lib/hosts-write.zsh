# Leer y escribir el archivo hosts con cuidado: copia de seguridad, escritura
# atómica y vaciado de la caché DNS.

# hosts_read archivo
# Deja en REPLY el contenido exacto, incluidos los saltos de línea finales.
hosts_read() {
  if [[ ! -f $1 || ! -r $1 ]]; then die "no se puede leer $1"; fi
  REPLY=$(cat -- $1; print -n x)   # la x evita que $(...) se coma los saltos de línea finales
  REPLY=${REPLY%x}
}

# hosts_backup_once contenido
# La primera vez que el motor modifica hosts, guarda el contenido anterior en
# DATA_DIR/hosts.original. Nunca la sobrescribe. El archivo es privado (600).
hosts_backup_once() {
  local backup=$DATA_DIR/hosts.original
  if [[ -e $backup ]]; then return 0; fi
  data_dir_ensure
  ( umask 077; print -rn -- "$1" > $backup )
}

# hosts_write_atomic archivo contenido
# Escribe un temporal en la misma carpeta y lo renombra encima del archivo.
# Renombrar es atómico: hosts nunca queda a medio escribir. Si algo falla, se
# borra el temporal y el archivo original queda intacto.
hosts_write_atomic() {
  local target=$1 content=$2 tmp
  tmp=$(mktemp "${target:h}/.hosts.guardian.XXXXXX")
  if ! { print -rn -- "$content" > $tmp &&
         chmod 644 $tmp &&
         set_root_owner $tmp &&
         mv -f -- $tmp $target }; then
    rm -f -- $tmp
    die "no se pudo escribir $target (no se modificó)"
  fi
}

# Siendo root, el archivo nuevo es de root:wheel, como el /etc/hosts original.
# El "--" va antes del dueño: el chown de macOS deja de leer opciones en el
# primer argumento normal, y un "--" detrás lo tomaría por un archivo.
set_root_owner() {
  if (( IS_ROOT )); then chown -- root:wheel $1; fi
}

# Vacía la caché DNS de macOS para que el cambio se note enseguida. Solo siendo
# root. Si falla, avisa pero no se considera un error: hosts ya está escrito.
dns_flush() {
  if (( ! IS_ROOT )); then return 0; fi
  dscacheutil -flushcache || warn "no se pudo vaciar la caché DNS (dscacheutil)"
  killall -HUP mDNSResponder || warn "no se pudo reiniciar mDNSResponder"
  return 0
}
