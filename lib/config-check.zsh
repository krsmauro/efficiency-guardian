# Validar los valores de la configuración, una vez leída (config.zsh).
# Cada valor ya pasó el filtro de caracteres de config_load; aquí se comprueban
# rangos, yes/no y la forma de los nombres de grupo. Muestra TODOS los errores.
#
# Que los grupos existan NO se comprueba aquí, sino en config_check_pass_groups
# (lo usan el instalador y "pass"): si alguien borra una lista, stop, cancel-stop
# y reconcile deben seguir funcionando.

# config_validate
# Usa CFG y deja, ya separados:
#   CFG_PRESETS      las duraciones de las sesiones por tiempo, en minutos
#   CFG_PASS_GROUPS  los grupos que desbloquea un pase
# Devuelve 1 si algo está mal.
config_validate() {
  local value errors=0

  config_check_int STOP_DELAY_MINUTES 0 60 || errors=1
  config_check_int PASS_MINUTES 1 60 || errors=1
  config_check_int PASS_MAX_PER_SESSION 0 20 || errors=1
  config_check_yes_no TIMED_LOCK || errors=1
  config_check_yes_no AUTOSTART_AT_BOOT || errors=1

  typeset -ga CFG_PRESETS=(${(us:,:)CFG[TIMED_PRESETS]})
  if (( $#CFG_PRESETS == 0 )); then err "TIMED_PRESETS: hace falta al menos una duración"; errors=1; fi
  for value in $CFG_PRESETS; do
    config_int_in_range "$value" 1 480 || { err "TIMED_PRESETS: ${(qq)value} no es un número entre 1 y 480"; errors=1 }
  done

  typeset -ga CFG_PASS_GROUPS=(${(us:,:)CFG[PASS_GROUPS]})
  if (( $#CFG_PASS_GROUPS == 0 )); then err "PASS_GROUPS: hace falta al menos un grupo"; errors=1; fi
  for value in $CFG_PASS_GROUPS; do
    # Minúsculas, como los nombres de grupo: el disco del Mac no distingue
    # mayúsculas, así que "Youtube.txt" existiría pero no coincidiría con nada.
    if [[ ! $value =~ '^[a-z0-9-]+$' ]]; then
      err "PASS_GROUPS: ${(qq)value} no es un nombre de grupo (minúsculas, números y guiones)"
      errors=1
    fi
  done

  return $errors
}

# config_check_pass_groups carpeta_de_listas → 1 (con un mensaje) si falta la lista de algún grupo.
config_check_pass_groups() {
  local group errors=0
  for group in $CFG_PASS_GROUPS; do
    if [[ ! -f $1/$group.txt ]]; then err "PASS_GROUPS: no existe el grupo ${(qq)group} en $1"; errors=1; fi
  done
  return $errors
}

# Minutos en la línea de comandos: de 1 a 3 cifras, sin ceros a la izquierda.
# La regla de sudoers usa este mismo patrón (install/sudoers.zsh), así que lo
# carga también el instalador.
readonly MINUTES_REGEX='^[1-9][0-9]?[0-9]?$'

# config_require_preset minutos → termina con un error si no está en TIMED_PRESETS.
# (start, extend y shorten solo admiten esas: sudo deja pasar cualquier número.)
config_require_preset() {
  if (( ! ${CFG_PRESETS[(Ie)$1]} )); then
    die "$1 min no es una duración permitida (TIMED_PRESETS: ${(j:, :)CFG_PRESETS})"
  fi
}

# config_int_in_range valor mínimo máximo → 0 si es un entero sin ceros a la izquierda y en el rango.
config_int_in_range() {
  if [[ ! $1 =~ '^(0|[1-9][0-9]{0,3})$' ]]; then return 1; fi
  if (( $1 < $2 || $1 > $3 )); then return 1; fi
  return 0
}

config_check_int() {
  if config_int_in_range "$CFG[$1]" $2 $3; then return 0; fi
  err "$1: ${(qq)CFG[$1]} no es un número entre $2 y $3"
  return 1
}

config_check_yes_no() {
  if [[ $CFG[$1] == (yes|no) ]]; then return 0; fi
  err "$1: ${(qq)CFG[$1]} debe ser yes o no"
  return 1
}
