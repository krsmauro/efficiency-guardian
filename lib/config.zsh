# Configuración: leerla y validarla línea por línea, sin "source".
#
# Archivo: /usr/local/etc/efficiency-guardian/config (root:wheel 644). El
# repositorio trae config.default, con la explicación de cada clave.
# Formato: CLAVE=valor, una por línea; los comentarios (#) van en su propia
# línea. Las claves que faltan toman el valor por defecto. Una clave
# desconocida, repetida o con un valor inválido es un error y no se carga nada.
#
# Nunca usar "source" con este archivo: ejecutaría su contenido como root.
# Por eso, además, el valor solo admite letras, números, comas y guiones.

typeset -grA CONFIG_DEFAULTS=(
  TIMED_PRESETS 25,50,90
  TIMED_LOCK no
  STOP_DELAY_MINUTES 5
  AUTOSTART_AT_BOOT yes
  PASS_MINUTES 5
  PASS_MAX_PER_SESSION 3
  PASS_GROUPS youtube
)

# config_load archivo
# Deja los valores en CFG (array asociativo) y, ya validados y separados,
# CFG_PRESETS y CFG_PASS_GROUPS (ver config-check.zsh). Si el archivo no
# existe, usa los valores por defecto. Si algo está mal, muestra TODOS los
# errores y devuelve 1.
config_load() {
  local file=$1 line key value line_number=0 errors=0
  local -A seen=()
  typeset -gA CFG=("${(@kv)CONFIG_DEFAULTS}")

  if [[ -e $file ]]; then
    if [[ ! -f $file || ! -r $file ]]; then err "no se puede leer $file"; return 1; fi
    while IFS= read -r line || [[ -n $line ]]; do
      line_number=$(( line_number + 1 ))
      line=${line%$'\r'}
      if [[ $line =~ '^[[:space:]]*(#.*)?$' ]]; then continue; fi
      if [[ ! $line =~ '^([A-Z_]+)=([A-Za-z0-9,-]*)[[:space:]]*$' ]]; then
        err "${file:t}:$line_number: línea inválida: ${(qq)line} (formato: CLAVE=valor)"
        errors=1
        continue
      fi
      key=$match[1] value=$match[2]
      if (( ! ${+CONFIG_DEFAULTS[$key]} )); then
        err "${file:t}:$line_number: clave desconocida: $key"; errors=1; continue
      fi
      if (( ${+seen[$key]} )); then
        err "${file:t}:$line_number: $key está repetida"; errors=1; continue
      fi
      seen[$key]=1
      CFG[$key]=$value
    done < $file
  fi

  config_validate || errors=1
  return $errors
}
