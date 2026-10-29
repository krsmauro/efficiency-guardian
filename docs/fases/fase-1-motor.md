# Fase 1: motor de bloqueo (`guardian`)

> Especificación para el agente que implemente esta fase. Antes de empezar, lee [02-integracion-macos.md](../investigacion/02-integracion-macos.md) (sección "Cómo dar permisos de root") y [01-metodos-de-bloqueo.md](../investigacion/01-metodos-de-bloqueo.md) (sección `/etc/hosts`).

## Objetivo

Un comando `guardian start|stop|status` que añade o quita un bloque gestionado en `/etc/hosts`. Debe ser seguro de ejecutar como root, idempotente y no tocar nunca nada fuera de su bloque.

> **Alcance de esta fase:** `start` inicia una sesión sin fin y `stop` desbloquea **de inmediato**. La [Fase 4](fase-4-sesiones-y-tiempo.md) añade después las sesiones por tiempo, el retraso al terminar, los pases y el arranque automático, sin cambiar los nombres de estos comandos. Escribe el código pensando en que crecerá: cada comando en su propia función y la escritura de hosts en una función reutilizable.

## Archivos en el repositorio

```
bin/guardian              # script zsh (motor)
blocklists/<grupo>.txt    # un archivo por grupo (youtube, facebook, ...), un dominio por línea
install.sh                # instalador (lo ejecuta el usuario con sudo)
uninstall.sh              # desinstalador (lo ejecuta el usuario con sudo)
tests/run.zsh             # pruebas sin root, sobre un hosts temporal
tests/fixtures/hosts      # copia del hosts real de esta Mac (ver docs/entorno.md)
```

## Rutas instaladas

| Ruta | Dueño y permisos | Contenido |
|---|---|---|
| `/usr/local/sbin/guardian` | `root:wheel 755` | El motor |
| `/usr/local/etc/efficiency-guardian/blocklists/*.txt` | `root:wheel 644` (carpetas `755`) | Listas activas |
| `/etc/sudoers.d/efficiency-guardian` | `root:wheel 440` | Regla NOPASSWD con argumentos exactos |
| `/var/db/efficiency-guardian/` | `root:wheel 700` | Copia de seguridad del hosts original (y, en la Fase 4, el estado) |

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

Cada caso copia `tests/fixtures/hosts` a una carpeta temporal y usa las variables `GUARDIAN_*`. Casos:

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
11. **Siendo root, las variables `GUARDIAN_*` se ignoran.** No se puede probar sin root: comprobarlo leyendo el código y verificarlo a mano en la instalación.

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
6. **Verificar** que `/usr/local/sbin` y `/usr/local/sbin/guardian` son de root y no escribibles por el grupo ni por otros.
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
