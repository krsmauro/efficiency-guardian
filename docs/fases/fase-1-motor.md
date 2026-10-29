# Fase 1: motor de bloqueo (`guardian`)

> Especificación para el agente que implemente esta fase. Antes de empezar, lee [02-integracion-macos.md](../investigacion/02-integracion-macos.md) (sección "Cómo dar permisos de root") y [01-metodos-de-bloqueo.md](../investigacion/01-metodos-de-bloqueo.md) (sección `/etc/hosts`).

## Objetivo

Un comando `guardian start|stop|status` que añade o quita un bloque gestionado en `/etc/hosts`. Debe ser seguro de ejecutar como root, idempotente y no tocar nunca nada fuera de su bloque.

> **Alcance de esta fase:** `start` inicia una sesión sin fin y `stop` desbloquea **de inmediato**. La [Fase 4](fase-4-sesiones-y-tiempo.md) añade después las sesiones por tiempo, el retraso al terminar, los pases y el arranque automático, sin cambiar los nombres de estos comandos. Escribe el código pensando en que crecerá, respetando la regla de tamaño (D13, abajo).

## Regla de tamaño (D13, requisito del usuario)

- **Cada archivo de código tiene una sola responsabilidad y unas 100 líneas como máximo. 150 es inaceptable.**
- Las líneas se cuentan con `wc -l`, incluidos comentarios y líneas en blanco.
- **Objetivo:** que el usuario pueda depurar a mano leyendo un archivo de principio a fin.
- **Cuenta como código:** `bin/`, `lib/`, `install*`, `uninstall*`, `tests/`, `close-tabs/` y `tools/` (añadidos el 2026-10-29, Fase 3) y, más adelante, `app/`.
- **No cuentan** los datos (`blocklists/*.txt`, `config.default`, `.plist`) ni la documentación (`*.md`).
- `tests/check-length.zsh` **falla si un archivo de código llega a 150 líneas y avisa si pasa de 100**. Corre con el resto de las pruebas, así que el instalador no instala código que rompa la regla. (2026-10-29: antes decía "pasa de 150", lo que dejaba pasar un archivo de exactamente 150; se alineó con "150 es inaceptable".)

## Archivos en el repositorio

```
bin/guardian                # punto de entrada: entorno seguro (PATH, umask, opciones), verifica y carga los módulos, despacha
lib/env.zsh                 # rutas: reales si es root, de prueba (GUARDIAN_*) si no; LC_ALL=C
lib/log.zsh                 # mensajes para la persona y registro con logger
lib/blocklist.zsh           # leer, normalizar y validar listas; lista "nunca bloquear"
lib/hosts-block.zsh         # texto puro: localizar, quitar y construir el bloque gestionado
lib/hosts-write.zsh         # leer, copia de seguridad, escritura atómica y vaciado de la caché DNS
lib/cmd-start.zsh           # subcomando start
lib/cmd-stop.zsh            # subcomando stop
lib/cmd-status.zsh          # subcomando status
blocklists/<grupo>.txt      # un archivo por grupo (youtube, facebook, ...), un dominio por línea
install.sh                  # instalador: solo llama a los pasos en orden (lo ejecuta el usuario con sudo)
install/paths.zsh           # rutas de instalación, compartidas por el instalador y el desinstalador
install/files.zsh           # copiar archivos con dueño y permisos
install/verify.zsh          # comprobar la cadena de dueños y permisos
install/migrate-hosts.zsh   # quitar las líneas manuales antiguas de YouTube
install/sudoers.zsh         # generar, validar e instalar la regla de sudoers
uninstall.sh                # desinstalador
tests/run.zsh               # ejecuta todos los tests/test-*.zsh y check-length.zsh
tests/assert.zsh            # funciones de aserción compartidas
tests/e2e.zsh               # ayudas de las pruebas de punta a punta (un caso = una carpeta temporal)
tests/test-blocklist.zsh    # pruebas de lib/blocklist.zsh
tests/test-hosts-block.zsh  # pruebas de lib/hosts-block.zsh
tests/test-commands.zsh     # start/stop/status de punta a punta, sobre un hosts temporal
tests/test-errors.zsh       # errores de punta a punta: el hosts siempre queda intacto
tests/test-install.zsh      # partes del instalador que no necesitan root
tests/test-syntax.zsh       # zsh -n de todo el código (el instalador no se puede ejecutar sin root)
tests/test-check-length.zsh # pruebas de la regla de tamaño
tests/check-length.zsh      # regla de tamaño
tests/fixtures/hosts        # copia del hosts real de esta Mac (ver docs/entorno.md)
```

Esta lista es una guía. Si un archivo se acerca a 100 líneas, divídelo por responsabilidad y actualiza esta lista.

**Ejecutar las pruebas:** `zsh tests/run.zsh` (sin root, unos segundos).

## Rutas instaladas

| Ruta | Dueño y permisos | Contenido |
|---|---|---|
| `/usr/local/sbin/guardian` | `root:wheel 755` | Punto de entrada |
| `/usr/local/libexec/efficiency-guardian/lib/*.zsh` | `root:wheel 644` (carpetas `755`) | Módulos del motor |
| `/usr/local/etc/efficiency-guardian/blocklists/*.txt` | `root:wheel 644` (carpetas `755`) | Listas activas |
| `/etc/sudoers.d/efficiency-guardian` | `root:wheel 440` | Regla NOPASSWD con argumentos exactos |
| `/var/db/efficiency-guardian/` | `root:wheel 700` | Copia de seguridad del hosts original (y, en la Fase 4, el estado) |

### Cargar módulos sin abrir un agujero de seguridad

Dividir el motor en módulos (D13) significa que `guardian`, corriendo como root, carga otros archivos con `source`. **Cada módulo cargado como root tiene el mismo poder que el script principal**, así que:

- **Primera línea `#!/bin/zsh -f`** en `bin/guardian`, `install.sh` y `uninstall.sh` (lo comprueba `tests/test-syntax.zsh`). El `-f` impide que zsh lea `~/.zshenv` y los demás archivos de arranque del usuario. Es necesario porque **sudo en macOS conserva `HOME`** (`Defaults env_keep += "HOME MAIL"` en el `/etc/sudoers` por defecto; conocido, pero no verificado leyendo el archivo, que no es legible sin root): sin `-f`, zsh ejecutaría como root el `~/.zshenv` del usuario, que cualquier programa suyo puede modificar.

- **Siendo root**, los módulos se cargan **solo** desde la ruta fija `/usr/local/libexec/efficiency-guardian/lib`. **Nunca** desde una ruta relativa, desde `$0` ni desde una variable de entorno.
- **Sin root** (pruebas), se aceptan `GUARDIAN_LIB_DIR` y las demás variables `GUARDIAN_*`. Así las pruebas usan `lib/` del repositorio.
- **Hecho:** siendo root, antes de cargarlos, `bin/guardian` comprueba que `/usr/local`, `/usr/local/libexec`, `…/efficiency-guardian`, `…/lib` y cada módulo son de root, no son enlaces y no son escribibles por el grupo ni por otros. Si no, aborta. Los módulos se cargan de una lista fija, no con un comodín.
- El instalador verifica toda la cadena: `/usr/local/libexec`, `…/efficiency-guardian`, `…/lib` y cada archivo.

## Interfaz

| Comando | ¿Root? | Efecto | Código de salida |
|---|---|---|---|
| `guardian start` | Sí | Escribe o reemplaza el bloque gestionado con todos los grupos de `blocklists/`. Si ya está igual, no escribe nada. | 0 si quedó activo; ≠0 si hubo error y no se tocó nada |
| `guardian stop` | Sí | Quita el bloque gestionado. Si no existe, no hace nada. | 0 si quedó inactivo |
| `guardian status` | No | Imprime `activo (N dominios)` o `inactivo`. | 0; 1 si los marcadores están dañados |
| Cualquier otra cosa (`guardian rm`, `guardian start 25`…) | — | Muestra el uso. En la Fase 1, `start` no admite argumentos. | 2 |

Los mensajes son en español. `/usr/local/sbin` no está en el `PATH` normal de macOS, así que se usa la ruta completa: `/usr/local/sbin/guardian status`.

## Formato del bloque en `/etc/hosts`

```
# >>> efficiency-guardian (gestionado automáticamente; no editar a mano) >>>
0.0.0.0 youtube.com
:: youtube.com
0.0.0.0 www.youtube.com
:: www.youtube.com
...
# <<< efficiency-guardian <<<
```

- Va **al final** del archivo, precedido de una línea en blanco.
- `stop` lo elimina por completo (no lo comenta), y el archivo vuelve a ser idéntico al original.

## Algoritmo (`start`; `stop` es igual pero sin bloque nuevo)

1. **Entorno seguro:** `#!/bin/zsh -f`, `PATH=/usr/bin:/bin:/usr/sbin:/sbin`, `umask 022`, `LC_ALL=C`, y en zsh `setopt ERR_EXIT NO_UNSET PIPE_FAIL`.
2. **Comprobar que corre como root.** Excepción solo para pruebas: si **no** es root, aceptar `GUARDIAN_HOSTS_FILE`, `GUARDIAN_BLOCKLIST_DIR`, `GUARDIAN_DATA_DIR` y `GUARDIAN_LIB_DIR`. **Si es root, ignorar esas variables.** (sudo quita esas variables, pero no todo el entorno: conserva `HOME`; ver arriba.)
   - Sin root nunca se vacía la caché DNS, ni se cambia el dueño de archivos, ni se escribe en el registro: sin root no se puede tocar el `/etc/hosts` real. Por eso `GUARDIAN_SKIP_FLUSH` ya no hace falta (2026-10-29).
   - `start` y `stop` sin root y sin `GUARDIAN_HOSTS_FILE` se niegan con "este comando necesita root: usa sudo".
3. **Leer las listas:**
   - Ignorar líneas vacías y comentarios (`#`).
   - Pasar a minúsculas y quitar duplicados.
   - Validar cada dominio con `^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$`.
   - **Si alguno es inválido, abortar sin tocar nada.**
   - Abortar también si un dominio está en la lista de "nunca bloquear" de [04-dominios.md](../investigacion/04-dominios.md). Esa lista va dentro del script: `accounts.youtube.com`, `youtube.googleapis.com`, `studio.youtube.com`, `upload.youtube.com`, `t.co`, `linkedin.com`, `www.linkedin.com`, `lnkd.in`.
4. **Leer `/etc/hosts` y localizar los marcadores.** Válido: 0 bloques, o exactamente 1 bloque con inicio antes que fin. Cualquier otra cosa (inicio sin fin, dos bloques…) → **error, sin tocar nada**.
5. **Construir el contenido nuevo:** todo lo que está fuera del bloque, byte a byte, más el bloque nuevo.
6. **Si es idéntico al actual, salir con 0** ("ya activo"). No reescribir.
7. **Copia de seguridad única:** si no existe `/var/db/efficiency-guardian/hosts.original`, copiar ahí el hosts actual.
8. **Escritura atómica:**
   - `mktemp /etc/.hosts.guardian.XXXXXX`.
   - Escribir, `chmod 644`, `chown root:wheel`.
   - `mv -f` sobre `/etc/hosts`.
9. **Vaciar la caché DNS:** `dscacheutil -flushcache; killall -HUP mDNSResponder`.
10. **Registrar:** `logger -t efficiency-guardian "efficiency-guardian: start: N dominios"`. El nombre va también dentro del mensaje porque la etiqueta de `-t` no aparece en el texto que filtra `log show` (verificado el 2026-10-29). Se ve con:
    ```
    /usr/bin/log show --last 1h --style compact --predicate 'process == "logger" AND eventMessage BEGINSWITH "efficiency-guardian"'
    ```
    Ruta completa a propósito: en zsh, `log` a secas es un comando interno (lista inicios de sesión) y falla con "too many arguments".

### Trampa de zsh encontrada al implementar (2026-10-29)

Si una expansión falla **dentro de la condición de un `if`** (por ejemplo `$words[1]` con `NO_UNSET` y el arreglo vacío), zsh muestra el error, da la condición por falsa y **sigue**, incluso con `ERR_EXIT`. En `is_legacy_line` eso hacía que las líneas de comentario de hosts contaran como "antiguas" y el instalador las habría borrado; las pruebas lo detectaron. Regla: no mezclar en la misma condición una comprobación de tamaño y el acceso al elemento (`(( $#a < 2 || ... $a[1] ))`); usar dos `if` separados.

## Pruebas (`tests/run.zsh`, sin root, sin dependencias)

Cada caso copia `tests/fixtures/hosts` a una carpeta temporal y usa las variables `GUARDIAN_*`. Cada archivo `tests/test-*.zsh` prueba un solo módulo y también respeta la regla de tamaño. Casos:

1. `start` añade el bloque con 2 líneas por dominio y deja el resto del archivo **byte a byte** igual.
2. `start` dos veces da el mismo archivo (idempotente) y la segunda vez no reescribe nada (misma fecha de modificación).
3. `start` seguido de `stop` deja el archivo idéntico al original.
4. `stop` sin bloque no hace nada.
5. Marcador de inicio sin fin → error y archivo intacto.
6. Dominio inválido en una lista (por ejemplo `you tube.com` o `*.youtube.com`) → error y archivo intacto.
7. Dominio prohibido (`accounts.youtube.com`) → error.
8. Comentarios, líneas vacías, mayúsculas y duplicados en las listas se normalizan.
9. Un hosts sin salto de línea final se maneja bien.
10. `status` refleja el estado correcto.
11. **Siendo root, las variables `GUARDIAN_*` (incluida `GUARDIAN_LIB_DIR`) se ignoran.** No se puede probar sin root: comprobarlo leyendo el código y verificarlo a mano en la instalación.
12. **Regla de tamaño:** `check-length.zsh` falla con un archivo de 150 líneas y avisa con uno de 101 (probarlo con archivos temporales).

**Además (2026-10-29):** la migración de líneas antiguas y la regla de sudoers (`test-install.zsh`, que valida la regla con `visudo -c -f`, que funciona sin root), la sintaxis de todo el código (`test-syntax.zsh`) y que `stop` funcione aunque las listas estén dañadas. Para comprobar que las pruebas detectan errores, se rompió el motor a propósito de 8 formas (sin línea IPv6, sin lista "nunca bloquear", reescribir siempre…) en una copia: todas las rompieron.

## Instalador (`install.sh`, lo ejecuta el usuario: `sudo ./install.sh`)

1. **Exigir root y un usuario destino:** `$SUDO_USER` no vacío y distinto de root.
2. **Ejecutar las pruebas como el usuario** (`sudo -u "$SUDO_USER" zsh -f tests/run.zsh`). Si fallan, abortar mostrando solo lo que falló.
3. **Crear carpetas e instalar archivos** con `install -o root -g wheel -m …` (rutas de la tabla de arriba).
   - Las carpetas compartidas (`/usr/local/sbin`, `/usr/local/libexec`, `/usr/local/etc`) se crean si faltan, pero **si ya existen no se tocan**: `install -d` cambiaría su dueño y permisos, y podrían ser de otro programa (por ejemplo Homebrew en un Mac Intel). El paso 4 comprueba que sean seguras.
   - Antes de copiar se borran los módulos y listas de una instalación anterior, para que un grupo eliminado del repositorio deje de bloquearse.
4. **Verificar** (antes que sudoers, a propósito: la regla solo se instala si lo instalado es seguro) que toda la cadena es de root, no son enlaces y no es escribible por el grupo ni por otros: `/usr/local`, el motor y su carpeta, `/usr/local/libexec/…/lib` y cada módulo, `/usr/local/etc/…/blocklists` y cada lista, y `/var/db/efficiency-guardian`. Si algo falla, **borrar la regla de sudoers** si quedaba de una instalación anterior, y abortar.
5. **Migrar las líneas manuales antiguas:**
   - Buscar en `/etc/hosts`, **fuera del bloque**, líneas `IP dominio [dominio…]` con una IP de bloqueo (`0.0.0.0`, `127.0.0.1`, `::`, `::1`) y **todos** los dominios en nuestras listas. Una línea que mezcle otros dominios no se toca. Hoy son 4 líneas de YouTube; ver [entorno.md](../entorno.md).
   - Mostrarlas y preguntar `¿Quitarlas? [s/N]` (se lee de `/dev/tty`; sin terminal, la respuesta es no).
   - Si la respuesta es sí: copia de seguridad en `/var/db/efficiency-guardian/hosts.before-install.<fecha-hora>` (con fecha para que una segunda migración no borre la primera copia) y quitar **solo** esas líneas, con escritura atómica.
   - Sin esto, `guardian stop` no desbloquearía YouTube.
6. **Instalar la regla de sudoers:**
   - Generar a partir de `$SUDO_USER` (solo se aceptan nombres `^[a-z_][a-z0-9_.-]*$`): `<usuario> ALL=(root) NOPASSWD: /usr/local/sbin/guardian start, /usr/local/sbin/guardian stop`.
   - Escribir en un temporal y validar con `visudo -c -f temporal`.
   - Instalar con `install -m 440 -o root -g wheel`.
   - Ejecutar `visudo -c`. Si falla, **borrar el archivo** y abortar.
7. **Imprimir los siguientes pasos:** la verificación manual de abajo y la Fase 2. **El instalador no activa el bloqueo.**

Se puede volver a ejecutar para actualizar lo instalado (por ejemplo, tras cambiar las listas).

**El desinstalador** ejecuta `guardian stop`, borra la regla de sudoers, el motor, sus módulos y las listas, y **conserva** `/var/db/efficiency-guardian/` (copias de seguridad). Si no puede quitar el bloque de hosts, no desinstala nada: sin el motor, habría que quitarlo a mano.

**Ensayo sin root (2026-10-29):** el instalador, el motor instalado y el desinstalador se ejecutaron enteros sobre una copia del repositorio con las rutas apuntando a una carpeta temporal, y con `chown`, `sudo`, `visudo` e `install` simulados. Funcionó todo: pruebas, copia, verificación, migración de las 4 líneas con su copia, regla de sudoers (`440`), `start`/`status`/`stop`, reinstalación sin cambios y desinstalación conservando las copias. También se comprobó que el motor se niega a cargar un módulo escribible por el grupo y que el instalador quita la regla de sudoers si una carpeta es escribible por todos. **Lo que no se pudo ensayar:** `chown` real, `visudo -c` sobre el sudoers completo, `dscacheutil`/`killall` y la regla de sudoers en uso. Eso se comprueba en 1.5 y 1.6.

**Fallo encontrado en 1.5 (2026-10-29), arreglado:** la primera instalación se detuvo en el paso de migrar las líneas manuales con `chown: --: No such file or directory`. `set_root_owner` hacía `chown root:wheel -- archivo`, y el `chown` de macOS deja de leer opciones en el primer argumento normal, así que tomaba el `--` por un archivo. Afectaba a **toda** escritura de hosts siendo root (`start`, `stop`, `pass`, `reconcile` y el instalador). Ahora es `chown -- root:wheel archivo`. Las pruebas no lo veían porque corren sin root y el ensayo simulaba `chown`. `tests/test-hosts-write.zsh` finge root y ejecuta el `chown` real (con el usuario actual): con la línea antigua falla igual que en la instalación. El intento fallido dejó copiados los archivos (pasos 4 y 5), sin LaunchDaemon cargado ni regla de sudoers, y `/etc/hosts` intacto.

## Verificación manual tras instalar (la hace el usuario)

> **Desde el 2026-10-29 el instalador instala las Fases 1 y 4 juntas.** Dos diferencias con esta lista:
> - `stop` ya no desbloquea en el acto: el bloqueo sigue **5 minutos** (`STOP_DELAY_MINUTES`). En los puntos que dicen "stop", espera 5 min y medio antes de comprobar.
> - `status` ahora muestra varias líneas (`Sesión: …`, `Bloqueo: …`).
>
> Si prefieres comprobar la Fase 1 sola, instálala desde su commit (`29b7ee0`) antes de actualizar; la Fase 4 conserva el bloqueo que haya al actualizar. La verificación de la Fase 4 está en [su especificación](fase-4-sesiones-y-tiempo.md#verificación-manual-tras-instalar-44-la-hace-el-usuario).

> **Resultados del 2026-10-29 (primera instalación):** marcados abajo. **Ojo al repetir la prueba de la contraseña:** sudo recuerda la contraseña 5 min, así que justo después de `sudo ./install.sh` la regla parece funcionar aunque no exista. Ejecutar antes `sudo -k`.

- [x] `sudo -n /usr/local/sbin/guardian start` funciona **sin pedir contraseña** (tras `sudo -k`).
- [x] `sudo -n /usr/local/sbin/guardian status` **sí pide contraseña o falla**, porque no está en la regla. Correcto: `status` se usa sin sudo. ("a password is required")
- [x] `sudo -n /usr/local/sbin/guardian rm` es rechazado.
- [x] `dscacheutil -q host -a name www.youtube.com` solo muestra `0.0.0.0` y `::`. (También youtube.com, web.whatsapp.com e www.instagram.com.)
- [x] Una pestaña nueva con youtube.com **no carga** en Brave, Vivaldi, Chrome y Thorium. Safari: probarlo también, y anotar si iCloud Private Relay está activo. (2026-10-29: no carga en ninguno de los cinco. Brave da `ERR_CONNECTION_REFUSED`. Falta saber si Private Relay estaba activo en Safari.)
  - **LinkedIn en Thorium da "403 Forbidden"** (en los otros cuatro carga). No es el bloqueo: LinkedIn no está en ninguna lista, y un 403 es una respuesta del servidor de LinkedIn, o sea que la conexión llegó. Sospecha: LinkedIn rechaza Thorium 138.0.7204.303 (Chromium de mediados de 2025, muy desactualizado). Se confirma si sigue igual sin sesión.
- [ ] Siguen funcionando: LinkedIn, Gmail, Drive, Meet, **YouTube Studio** (subir un video de prueba como privado, y ver la vista previa), y el inicio de sesión de Google en una ventana privada.
  - YouTube Studio con la sesión ya iniciada: **funciona** (Brave).
  - **Iniciar sesión en YouTube Studio sin sesión** (ventana privada de Brave): **falla.** Tras el inicio de sesión de Google, la redirección pasa por `www.youtube.com/signin?...&next=https://studio.youtube.com/`, que está bloqueado. Hosts no puede desbloquear una sola página, así que no hay arreglo barato. Solución: un pase. Comprobado en parte el 2026-10-29: con el pase, `www.youtube.com` carga; el inicio de sesión en Studio no se probó expresamente. Limitación aceptada como rara (solo cuando Google cierra la sesión).
  - LinkedIn, Gmail, Meet y `accounts.google.com` resuelven con normalidad (`dscacheutil`); falta abrirlos en el navegador.
- [ ] No cargan: cada grupo de `blocklists/`, incluido WhatsApp Web. Para Pinterest, anotar a qué subdominio de país redirige.
- [x] `sudo -n /usr/local/sbin/guardian stop` y YouTube vuelve a cargar (quizá haga falta recargar). (2026-10-29: tras el retraso de 5 min, sin hacer nada.)
- [ ] `/etc/hosts` queda idéntico a como estaba antes de `start`. (2026-10-29: mismo tamaño que `hosts.original`, 213 bytes, y sin bloque. Falta `sudo diff /var/db/efficiency-guardian/hosts.original /etc/hosts` para confirmarlo.)
- [x] El registro muestra el `start` y el `stop`: `/usr/bin/log show --last 1h --style compact --predicate 'process == "logger" AND eventMessage BEGINSWITH "efficiency-guardian"'`.
- [ ] (Opcional) `sudo printenv HOME` muestra `/Users/<usuario>` y no `/var/root`: confirma que sudo conserva `HOME` y por qué hace falta el `-f`.

Anota los resultados en la bitácora de [PLAN.md](../../PLAN.md). Si algo de la investigación resultó falso, corrígelo en `docs/investigacion/`.
