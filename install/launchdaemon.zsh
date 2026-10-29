# Paso 7 del instalador: cargar el LaunchDaemon, que ejecuta "guardian
# reconcile" como root al cargarse y luego cada 30 s (ver launchd/*.plist).
# install_files ya copió el plist y install_verify comprobó sus permisos.
#
# daemon_unload lo usan también el instalador (antes de copiar archivos, para
# que no ejecute una mezcla de versiones), install_verify y el desinstalador.

daemon_loaded() {
  launchctl print system/$DAEMON_LABEL > /dev/null 2>&1
}

daemon_unload() {
  if daemon_loaded; then
    launchctl bootout system/$DAEMON_LABEL || warn "launchctl no pudo descargar $DAEMON_LABEL"
  fi
  return 0
}

daemon_load() {
  local attempt
  daemon_unload
  # Por si alguna vez se desactivó con "launchctl disable".
  launchctl enable system/$DAEMON_LABEL || warn "launchctl enable falló; se intenta cargar igual"
  # Justo después de un bootout, bootstrap a veces falla porque launchd aún no
  # terminó de descargarlo: se reintenta unas veces.
  for attempt in 1 2 3 4 5; do
    if launchctl bootstrap system $PLIST_FILE 2> /dev/null; then break; fi
    if (( attempt == 5 )); then die "launchctl no pudo cargar $PLIST_FILE"; fi
    sleep 1
  done
  if ! daemon_loaded; then die "el LaunchDaemon no aparece cargado ($DAEMON_LABEL)"; fi
  say "   $DAEMON_LABEL cargado: ejecuta 'guardian reconcile' cada 30 s"
}
