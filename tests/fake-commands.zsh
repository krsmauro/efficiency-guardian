# Ayudas para tests/test-close-tabs.zsh: osascript y lsappinfo de mentira, y
# close-tabs.zsh ejecutado sobre un hosts temporal. Se carga después de assert.zsh.

F=$T_TMP/fake
mkdir -p $F

# lsappinfo de mentira: las apps abiertas son las que estén en $F/running.
cat > $F/lsappinfo <<EOF
#!/bin/zsh -f
bundle=\${2#bundleid=}
if grep -qxF -- "\$bundle" $F/running 2>/dev/null; then print -r -- "ASN:0x0-0x1-\"\$bundle\":"; fi
EOF

# osascript de mentira: anota en $F/calls cuántos -e recibió y los demás argumentos,
# guarda los scripts en $F/script-N y responde $F/out-<bundle> con el código
# $F/status-<bundle>. Sin esos archivos responde 0 (ninguna pestaña cerrada).
cat > $F/osascript <<EOF
#!/bin/zsh -f
args=() n=0
while (( \$# )); do
  case \$1 in
    (-l) shift 2 ;;
    (-e) n=\$(( n + 1 )); print -r -- "\$2" > $F/script-\$n; shift 2 ;;
    (*) args+=("\$1"); shift ;;
  esac
done
print -r -- "\$n \${args[*]}" >> $F/calls
if [[ -r $F/out-\$args[1] ]]; then print -r -- "\$(<$F/out-\$args[1])"; else print 0; fi
exit \$(cat $F/status-\$args[1] 2>/dev/null || print 0)
EOF
chmod +x $F/lsappinfo $F/osascript

# new_case contenido_del_hosts navegador_abierto...
new_case() {
  rm -f -- $F/calls $F/running $F/out-*(N) $F/status-*(N) $F/script-*(N)   # (N): sin error si no hay
  print -rn -- "$1" > $T_TMP/hosts
  shift
  for bundle in "$@"; do print -r -- $bundle >> $F/running; done
}

# run_close_tabs → deja la salida normal en OUT, la de errores en ERR, el código
# en ST y las llamadas a osascript en CALLS.
run_close_tabs() {
  OUT=$(GUARDIAN_HOSTS_FILE=$T_TMP/hosts GUARDIAN_OSASCRIPT=$F/osascript GUARDIAN_LSAPPINFO=$F/lsappinfo \
        /bin/zsh -f $REPO/close-tabs/close-tabs.zsh 2>$T_TMP/err)
  ST=$?
  ERR=$(<$T_TMP/err)
  CALLS=$(cat $F/calls 2>/dev/null)
}
