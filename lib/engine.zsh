# El ciclo común de los comandos:
#   engine_begin   candado, configuración, reloj y estado, y lo que el tiempo cambió
#   engine_commit  calcular el hosts que corresponde, guardar el estado,
#                  escribir hosts (solo si cambia) y registrar lo que pasó
#
# hosts siempre se DERIVA del estado. Si alguien lo edita a mano, o una
# escritura falló a medias, el siguiente comando (o reconcile, cada 30 s) lo
# deja como debe estar.

engine_begin() {
  require_write_access
  engine_lock
  engine_read
}

# Lo mismo, sin candado ni permiso de escritura: lo usa status (sin root).
engine_read() {
  config_load $CONFIG_FILE || die "configuración inválida en $CONFIG_FILE: no se hizo nada"
  clock_init
  state_load
  session_init
  session_advance
}

# engine_plan
# Calcula, sin escribir nada:
#   PLAN_CURRENT  el hosts actual
#   PLAN_CONTENT  el hosts que corresponde al estado
#   PLAN_COUNT    cuántos dominios quedan bloqueados
# Sin sesión: sin bloque, y sin leer las listas (así siempre se puede
# desbloquear, aunque estén dañadas). Con sesión: todos los grupos, menos
# PASS_GROUPS si hay un pase en curso.
# Si las listas están dañadas y ya hay un bloque, se deja como está (así stop
# y cancel-stop siguen funcionando); si no hay bloque, error: no hay qué poner.
engine_plan() {
  local -a skip=()
  hosts_read $HOSTS_FILE
  PLAN_CURRENT=$REPLY
  hosts_parse "$PLAN_CURRENT" || die "$HOSTS_ERROR"
  PLAN_CONTENT=$HOSTS_OUTSIDE PLAN_COUNT=0
  if [[ $S[SESSION] == none ]]; then return 0; fi

  if pass_active; then skip=($CFG_PASS_GROUPS); fi
  if ! blocklist_load $BLOCKLIST_DIR $skip; then
    if (( ! HOSTS_ACTIVE )); then die "no se cambió nada: corrige las listas de $BLOCKLIST_DIR"; fi
    warn "las listas de $BLOCKLIST_DIR tienen errores: el bloqueo se queda como estaba"
    PLAN_CONTENT=$PLAN_CURRENT PLAN_COUNT=$HOSTS_COUNT
    return 0
  fi
  PLAN_COUNT=$#BLOCKED_DOMAINS
  if (( PLAN_COUNT > 0 )); then
    hosts_with_block "$HOSTS_OUTSIDE" "${BLOCKED_DOMAINS[@]}"
    PLAN_CONTENT=$REPLY
  fi
}

# engine_commit
# Todo lo que puede fallar (hosts dañado, listas inválidas) falla en
# engine_plan, antes de escribir nada. Luego el estado y, por último, hosts.
engine_commit() {
  local change
  engine_plan
  state_save
  if [[ $PLAN_CONTENT != "$PLAN_CURRENT" ]]; then
    hosts_backup_once "$PLAN_CURRENT"
    hosts_write_atomic $HOSTS_FILE "$PLAN_CONTENT"
    dns_flush
    if (( PLAN_COUNT > 0 )); then CHANGES+="hosts: $PLAN_COUNT dominios bloqueados"; else CHANGES+="hosts: sin bloqueo"; fi
  fi
  for change in $CHANGES; do log_event "$change"; done
}
