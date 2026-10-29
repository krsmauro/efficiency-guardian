# Fase 1: motor de bloqueo (`guardian`)

> Especificación para el agente que implemente esta fase. Antes de empezar, lee [02-integracion-macos.md](../investigacion/02-integracion-macos.md) (sección "Cómo dar permisos de root") y [01-metodos-de-bloqueo.md](../investigacion/01-metodos-de-bloqueo.md) (sección `/etc/hosts`).

## Objetivo

Un comando `guardian start|stop|status` que añade o quita un bloque gestionado en `/etc/hosts`. Debe ser seguro de ejecutar como root, idempotente y no tocar nunca nada fuera de su bloque.

> **Alcance de esta fase:** `start` inicia una sesión sin fin y `stop` desbloquea **de inmediato**. La [Fase 4](fase-4-sesiones-y-tiempo.md) añade después las sesiones por tiempo, el retraso al terminar, los pases y el arranque automático, sin cambiar los nombres de estos comandos. Escribe el código pensando en que crecerá, respetando la regla de tamaño (D13, abajo).

## Regla de tamaño (D13, requisito del usuario)

- **Cada archivo de código tiene una sola responsabilidad y unas 100 líneas como máximo. 150 es inaceptable.**
- Las líneas se cuentan con `wc -l`, incluidos comentarios y líneas en blanco.
- **Objetivo:** que el usuario pueda depurar a mano leyendo un archivo de principio a fin.
- **Cuenta como código:** `bin/`, `lib/`, `install*`, `uninstall*`, `tests/` y, más adelante, `app/`.
- **No cuentan** los datos (`blocklists/*.txt`, `config.default`, `.plist`) ni la documentación (`*.md`).
- `tests/check-length.zsh` **falla si un archivo de código pasa de 150 líneas y avisa si pasa de 100**. Corre con el resto de las pruebas, así que el instalador no instala código que rompa la regla.

## Archivos en el repositorio

```
bin/guardian              # punto de entrada: carga los módulos y despacha el subcomando
lib/env.zsh               # entorno seguro (PATH, umask, opciones) y rutas: reales si es root, de prueba si no
lib/log.zsh               # mensajes de error e información, y registro con logger
lib/blocklist.zsh         # leer, normalizar y validar listas; lista "nunca bloquear"
lib/hosts-block.zsh       # texto puro: localizar, quitar y construir el bloque gestionado
lib/hosts-write.zsh       # copia de seguridad, escritura atómica de /etc/hosts y vaciado de la caché DNS
lib/cmd-start.zsh         # subcomando start
lib/cmd-stop.zsh          # subcomando stop
lib/cmd-status.zsh        # subcomando status
blocklists/<grupo>.txt    # un archivo por grupo (youtube, facebook, ...), un dominio por línea
install.sh                # instalador: solo llama a los pasos en orden (lo ejecuta el usuario con sudo)
install/files.zsh         # copiar archivos con dueño y permisos
install/migrate-hosts.zsh # quitar las líneas manuales antiguas de YouTube
install/sudoers.zsh       # generar, validar e instalar la regla de sudoers
install/verify.zsh        # comprobar la cadena de dueños y permisos
uninstall.sh              # desinstalador
tests/run.zsh             # ejecuta todos los tests/test-*.zsh y check-length.zsh
tests/assert.zsh          # funciones de aserción compartidas
tests/test-blocklist.zsh  # pruebas de lib/blocklist.zsh
tests/test-hosts-block.zsh# pruebas de lib/hosts-block.zsh
tests/test-commands.zsh   # pruebas de start/stop/status de punta a punta, sobre un hosts temporal
tests/check-length.zsh    # regla de tamaño
tests/fixtures/hosts      # copia del hosts real de esta Mac (ver docs/entorno.md)
```

Esta lista es una guía. Si un archivo se acerca a 100 líneas, divídelo por responsabilidad y actualiza esta lista.

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

- **Siendo root**, los módulos se cargan **solo** desde la ruta fija `/usr/local/libexec/efficiency-guardian/lib`. **Nunca** desde una ruta relativa, desde `$0` ni desde una variable de entorno.
- **Sin root** (pruebas), se aceptan `GUARDIAN_LIB_DIR` y las demás variables `GUARDIAN_*`. Así las pruebas usan `lib/` del repositorio.
- **Recomendado:** siendo root, antes de cargarlos, comprobar que la carpeta y cada módulo son de root y no escribibles por el grupo ni por otros. Si no, abortar.
- El instalador verifica toda la cadena: `/usr/local/libexec`, `…/efficiency-guardian`, `…/lib` y cada archivo.

## Interfaz

| Comando | ¿Root? | Efecto | Código de salida |
|---|---|---|---|
| `guardian start` | Sí | Escribe o reemplaza el bloque gestionado con todos los grupos de `blocklists/`. Si ya está igual, no escribe nada. | 0 si quedó activo; ≠0 si hubo error y no se tocó nada |
| `guardian stop` | Sí | Quita el bloque gestionado. Si no existe, no hace nada. | 0 si quedó inactivo |
| `guardian status` | No | Imprime `activo (N dominios)` o `inactivo`. | 0 |

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

1. **Entorno seguro:** `PATH=/usr/bin:/bin:/usr/sbin:/sbin`, `umask 022`, y en zsh `setopt ERR_EXIT NO_UNSET PIPE_FAIL`.
2. **Comprobar que corre como root.** Excepción solo para pruebas: si **no** es root, aceptar `GUARDIAN_HOSTS_FILE`, `GUARDIAN_BLOCKLIST_DIR` y `GUARDIAN_SKIP_FLUSH=1`. **Si es root, ignorar esas variables.** (sudo ya limpia el entorno, pero esto es una segunda barrera.)
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
10. **Registrar:** `logger -t efficiency-guardian "start: N dominios"`. Se ve con `log show --predicate 'process == "logger"' --last 1h`.

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
12. **Regla de tamaño:** `check-length.zsh` falla con un archivo de 151 líneas y avisa con uno de 101 (probarlo con archivos temporales).

## Instalador (`install.sh`, lo ejecuta el usuario: `sudo ./install.sh`)

1. **Exigir root y un usuario destino:** `$SUDO_USER` no vacío y distinto de root.
2. **Ejecutar las pruebas como el usuario** (`sudo -u "$SUDO_USER" zsh tests/run.zsh`). Si fallan, abortar.
3. **Crear carpetas e instalar archivos** con `install -o root -g wheel -m …` (rutas de la tabla de arriba).
4. **Migrar las líneas manuales antiguas:**
   - Buscar en `/etc/hosts`, **fuera del bloque**, líneas que bloqueen dominios de nuestras listas. Hoy son 4 líneas de YouTube; ver [entorno.md](../entorno.md).
   - Mostrarlas y preguntar `¿Quitarlas? [s/N]`.
   - Si la respuesta es sí: copia de seguridad en `/var/db/efficiency-guardian/hosts.before-install` y quitar **solo** esas líneas, con escritura atómica.
   - Sin esto, `guardian stop` no desbloquearía YouTube.
5. **Instalar la regla de sudoers:**
   - Generar a partir de `$SUDO_USER`: `<usuario> ALL=(root) NOPASSWD: /usr/local/sbin/guardian start, /usr/local/sbin/guardian stop`.
   - Escribir en un temporal y validar con `visudo -c -f temporal`.
   - Instalar con `install -m 440 -o root -g wheel`.
   - Ejecutar `visudo -c`. Si falla, **borrar el archivo** y abortar.
6. **Verificar** que `/usr/local/sbin`, `/usr/local/sbin/guardian`, `/usr/local/libexec/efficiency-guardian/lib` y cada módulo son de root y no escribibles por el grupo ni por otros.
7. **Imprimir los siguientes pasos:** la verificación manual de abajo y la Fase 2.

**El desinstalador** ejecuta `guardian stop`, borra la regla de sudoers, el script y la configuración, y **conserva** `/var/db/efficiency-guardian/` (copias de seguridad).

## Verificación manual tras instalar (la hace el usuario)

- [ ] `sudo -n /usr/local/sbin/guardian start` funciona **sin pedir contraseña**.
- [ ] `sudo -n /usr/local/sbin/guardian status` **sí pide contraseña o falla**, porque no está en la regla. Correcto: `status` se usa sin sudo.
- [ ] `sudo -n /usr/local/sbin/guardian rm` es rechazado.
- [ ] `dscacheutil -q host -a name www.youtube.com` solo muestra `0.0.0.0` y `::`.
- [ ] Una pestaña nueva con youtube.com **no carga** en Brave, Vivaldi, Chrome y Thorium. Safari: probarlo también, y anotar si iCloud Private Relay está activo.
- [ ] Siguen funcionando: LinkedIn, Gmail, Drive, Meet, **YouTube Studio** (subir un video de prueba como privado, y ver la vista previa), y el inicio de sesión de Google en una ventana privada.
- [ ] No cargan: cada grupo de `blocklists/`, incluido WhatsApp Web. Para Pinterest, anotar a qué subdominio de país redirige.
- [ ] `sudo -n /usr/local/sbin/guardian stop` y YouTube vuelve a cargar (quizá haga falta recargar).
- [ ] `/etc/hosts` queda idéntico a como estaba antes de `start`.

Anota los resultados en la bitácora de [PLAN.md](../../PLAN.md). Si algo de la investigación resultó falso, corrígelo en `docs/investigacion/`.
