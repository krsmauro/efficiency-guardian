# Subcomando pass [grupo]: un pase temporal (D5).
#
# Desbloquea un grupo de PASS_GROUPS (sin argumento, el primero: por defecto,
# YouTube) durante PASS_MINUTES; al vencer, reconcile lo vuelve a bloquear.
# Un pase a la vez y, como mucho, PASS_MAX_PER_SESSION por sesión, sumando
# todos los grupos: más sitios no dan más pases (Fase 6, B). Requiere una
# sesión. Se puede usar durante una terminación pendiente.

cmd_pass() {
  local group max used message
  engine_begin
  group=${1:-$CFG_PASS_GROUPS[1]} max=$CFG[PASS_MAX_PER_SESSION] used=$S[PASSES_USED]

  if (( ! ${CFG_PASS_GROUPS[(Ie)$group]} )); then
    die "$group no tiene pases (PASS_GROUPS: ${(j:, :)CFG_PASS_GROUPS})"
  fi
  if [[ $S[SESSION] == none ]]; then die "no hay sesión: no hace falta un pase"; fi
  if pass_active; then
    hhmm $S[PASS_UNTIL]
    die "ya hay un pase en curso: $S[PASS_GROUP], hasta las $REPLY"
  fi
  if (( used >= max )); then die "no quedan pases en esta sesión ($used/$max)"; fi
  # Con una lista dañada, engine_plan dejaría el bloque como está: el pase se
  # contaría sin desbloquear nada. Mejor no gastarlo.
  config_check_pass_groups $BLOCKLIST_DIR || die "no se gastó el pase: corrige PASS_GROUPS"
  blocklist_load $BLOCKLIST_DIR || die "no se gastó el pase: corrige las listas de $BLOCKLIST_DIR"

  used=$(( used + 1 ))
  S[PASSES_USED]=$used S[PASS_GROUP]=$group
  S[PASS_UNTIL]=$(( NOW + CFG[PASS_MINUTES] * 60 ))
  hhmm $S[PASS_UNTIL]
  CHANGES+="pass $group: $used/$max, hasta las $REPLY"
  message="Pase: $group desbloqueado hasta las $REPLY. Te quedan $(( max - used )) de $max."

  engine_commit
  say "$message"
}
