# Candado: que dos guardian no se pisen.
#
# El LaunchDaemon ejecuta reconcile cada 30 s, y a la vez puede llegar un
# atajo o la app. Si los dos leen el mismo estado y escriben después, uno
# borra el cambio del otro (por ejemplo, un pase contado). Por eso los
# comandos que escriben toman este candado ANTES de leer el estado.
#
# El candado se suelta solo cuando el proceso termina, incluso si termina con
# error. Es un candado de fcntl con "zsystem flock" (módulo de zsh incluido en
# macOS): no hace falta lockf ni otro programa externo.

zmodload zsh/system

readonly LOCK_WAIT_SECONDS=10

engine_lock() {
  local file=$DATA_DIR/lock
  data_dir_ensure
  if [[ ! -e $file ]]; then ( umask 077; : >> $file ); fi
  if ! zsystem flock -t $LOCK_WAIT_SECONDS -f LOCK_FD $file; then
    die "otro guardian lleva más de $LOCK_WAIT_SECONDS s en curso; inténtalo de nuevo"
  fi
}
