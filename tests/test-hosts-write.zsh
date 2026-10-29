#!/bin/zsh -f
# Pruebas de lib/hosts-write.zsh por el camino de root, sin ser root.
# Las demás pruebas corren sin root y nunca llegaban a ejecutar chown. Así se
# escapó un fallo que impedía toda escritura de hosts: lo encontró el usuario
# al instalar (paso 1.5, 2026-10-29).

source ${0:A:h}/assert.zsh
for module in env log hosts-write; do source $REPO/lib/$module.zsh; done

# Fingir root solo en este archivo. chown es el de verdad, para que compruebe el
# orden de los argumentos, pero con el usuario actual en vez de root:wheel (sin
# root no se puede poner). logger no hace nada: las pruebas no tocan el registro.
IS_ROOT=1
chown() { command chown "${@/#%root:wheel/$(id -un):$(id -gn)}"; }
logger() { :; }

section "Escribir hosts siendo root (lo hacen start, stop, reconcile y el instalador)"
target=$T_TMP/hosts
print -r -- "viejo" > $target
output=$(hosts_write_atomic $target $'nuevo\n' 2>&1)
assert_status "escribe sin error" 0 $? "$output"
hosts_read $target
assert_eq "el contenido es el nuevo" $'nuevo\n' "$REPLY"
assert_eq "permisos 644, como /etc/hosts" 644 $(mode_of $target)
leftovers=($T_TMP/.hosts.guardian.*(N))
assert_eq "no quedan temporales" 0 $#leftovers

finish
