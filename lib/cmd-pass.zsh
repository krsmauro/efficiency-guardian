# Subcomando pass: un pase temporal (D5).
#
# Desbloquea los grupos de PASS_GROUPS (por defecto, solo YouTube) durante
# PASS_MINUTES; al vencer, reconcile los vuelve a bloquear. Como mucho
# PASS_MAX_PER_SESSION pases por sesión. Requiere una sesión y que no haya otro
# pase en curso. Se puede usar durante una terminación pendiente.

cmd_pass() {
  local max used message
  engine_begin
  max=$CFG[PASS_MAX_PER_SESSION] used=$S[PASSES_USED]

  if [[ $S[SESSION] == none ]]; then die "no hay sesión: no hace falta un pase"; fi
  if pass_active; then
    hhmm $S[PASS_UNTIL]
    die "ya hay un pase en curso, hasta las $REPLY"
  fi
  if (( used >= max )); then die "no quedan pases en esta sesión ($used/$max)"; fi
  # Con una lista dañada, engine_plan dejaría el bloque como está: el pase se
  # contaría sin desbloquear nada. Mejor no gastarlo.
  config_check_pass_groups $BLOCKLIST_DIR || die "no se gastó el pase: corrige PASS_GROUPS"
  blocklist_load $BLOCKLIST_DIR || die "no se gastó el pase: corrige las listas de $BLOCKLIST_DIR"

  used=$(( used + 1 ))
  S[PASSES_USED]=$used
  S[PASS_UNTIL]=$(( NOW + CFG[PASS_MINUTES] * 60 ))
  hhmm $S[PASS_UNTIL]
  CHANGES+="pass: $used/$max, hasta las $REPLY"
  message="Pase: ${(j:, :)CFG_PASS_GROUPS} desbloqueado hasta las $REPLY. Te quedan $(( max - used )) de $max."

  engine_commit
  say "$message"
}
