# Rutas de instalación, compartidas por install.sh, uninstall.sh y los pasos de install/.
# Deben coincidir con bin/guardian (INSTALLED_LIB) y lib/env.zsh (REAL_*):
# tests/test-install.zsh lo comprueba.

readonly SBIN_DIR=/usr/local/sbin
readonly ENGINE=$SBIN_DIR/guardian
readonly LIBEXEC_DIR=/usr/local/libexec/efficiency-guardian
readonly LIB_DIR=$LIBEXEC_DIR/lib
readonly ETC_DIR=/usr/local/etc/efficiency-guardian
readonly LISTS_DIR=$ETC_DIR/blocklists
readonly CONFIG_INSTALLED=$ETC_DIR/config

# Sin punto en el nombre: sudo ignora en silencio los archivos de sudoers.d con punto.
readonly SUDOERS_FILE=/etc/sudoers.d/efficiency-guardian

# LaunchDaemon de la Fase 4: ejecuta "guardian reconcile" cada 30 s.
readonly DAEMON_LABEL=com.efficiency-guardian.reconcile
readonly DAEMONS_DIR=/Library/LaunchDaemons
readonly PLIST_FILE=$DAEMONS_DIR/$DAEMON_LABEL.plist
