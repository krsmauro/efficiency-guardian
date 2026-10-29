# Fase 4: sesiones, tiempo y pases

> **Código escrito el 2026-10-29 (pasos 4.0 a 4.3).** Falta la verificación manual del usuario (4.4). La especificación original es del 2026-10-28; los cambios hechos al implementar están marcados con **(cambio)** y su motivo. Requiere la Fase 1 (y conviene la 2). Conviene tener la [Fase 3](fase-3-cerrar-pestanas.md): sin ella, una pestaña abierta sigue reproduciendo cuando vence un pase o termina una sesión.

## Requisitos del usuario (2026-10-28)

1. **Dos tipos de sesión:**
   - **Por tiempo:** bloquear N minutos, con duraciones predefinidas.
   - **Indefinida:** sin hora de fin.
2. **Sesión indefinida automática al encender el Mac:**
   - Configurable, **activada por defecto** (D11).
   - Termina al apagar el Mac, o cuando el usuario pide terminarla.
3. **Terminar antes de tiempo:**
   - Configurable, y con un **"tiempo de candado"**: al pedir terminar, el bloqueo sigue **5 minutos más** (configurable) para dar tiempo a arrepentirse y seguir trabajando (D10).
   - Una sesión por tiempo puede además llevar **candado completo** (configurable): no se puede terminar antes de la hora.
4. **Pases** (D5): 5 min por defecto, máximo 3 por sesión, ambos configurables. Por defecto solo para YouTube.
5. **Todo configurable.**

## Supuestos: confirmados por el usuario el 2026-10-29

- **S1, confirmado:** el retraso al terminar se aplica a **todas** las sesiones, también a la indefinida y a "desactivar la Concentración".
- **S2, confirmado:** si hay una sesión indefinida en curso y se pide una **por tiempo**, la indefinida **se convierte** en una por tiempo que termina dentro de N minutos. Al terminar, **se desbloquea** ("50 min" significa "trabajo 50 minutos más y quedo libre").
  - Conserva el contador de pases y el pase en curso, para que no sirva para reiniciarlos.
  - Anula una terminación pendiente.
  - **(cambio)** Nunca termina antes que `STOP_DELAY_MINUTES`: si no, una duración corta (por ejemplo `TIMED_PRESETS=1`) sería un atajo para saltarse el retraso.
  - Con otra por tiempo ya en curso, se rechaza: no se puede acortar una sesión con candado.
- **S3, descartado:** el supuesto era que el Mac casi nunca se apaga. **Resultó falso:** el historial (`last reboot shutdown`) muestra que el Mac se apaga casi todas las noches y arranca cada mañana (36 días, del 23-09 al 29-10; el mayor tiempo encendido fue de unas 26 h). La sesión automática ya dura un día y los pases se reinician solos cada día. **No hay reinicio a las 4 a. m.** (`PASS_RESET_HOUR` no existe). Si el uso cambia (el Mac pasa días dormido), se reconsidera.

## Configuración: `/usr/local/etc/efficiency-guardian/config` (`root:wheel 644`)

El repositorio trae [config.default](../../config.default), con un comentario por clave. El instalador la copia **solo si no existe**: nunca sobrescribe la del usuario.

| Clave | Por defecto | Valores válidos |
|---|---|---|
| `TIMED_PRESETS` | `25,50,90` | Números del 1 al 480, separados por comas (se quitan los repetidos) |
| `TIMED_LOCK` | `no` | `yes` / `no` |
| `STOP_DELAY_MINUTES` | `5` | 0 a 60 (0 = inmediato) |
| `AUTOSTART_AT_BOOT` | `yes` | `yes` / `no` |
| `PASS_MINUTES` | `5` | 1 a 60 |
| `PASS_MAX_PER_SESSION` | `3` | 0 a 20 (0 = sin pases) |
| `PASS_GROUPS` | `youtube` | Grupos de `blocklists/`, en minúsculas, separados por comas |

- **Se lee línea por línea, nunca con `source`** (ejecutaría su contenido como root). Formato estricto: `CLAVE=valor`, el valor solo admite letras, números, comas y guiones, y los comentarios van en su propia línea. Una clave desconocida, repetida o un valor inválido es un error: **el motor no hace nada** hasta que se corrija, y el instalador se niega a empezar.
- **(cambio, tras la revisión)** Que los grupos de `PASS_GROUPS` existan **no** se comprueba al leer la configuración, sino en el instalador y en `pass`. Si no, borrar una lista dejaría sin funcionar `stop`, `cancel-stop` y `reconcile`.
- Los números no admiten ceros a la izquierda (`05` es un error).
- **(cambio)** Los grupos deben ir en minúsculas: el disco del Mac no distingue mayúsculas, así que `Youtube` pasaría la comprobación del archivo pero no coincidiría con ningún grupo.
- Cambiar la configuración requiere `sudo`. Es fricción deseada.
- **Si se cambia `TIMED_PRESETS`, hay que volver a ejecutar el instalador,** que regenera la regla de sudoers.

## Estado: `/var/db/efficiency-guardian/state` (`root:wheel 644`)

La carpeta pasa a ser `755` (el instalador la cambia; en la Fase 1 era `700`) y las copias de seguridad siguen en `600`. El estado debe ser legible sin root, porque la app de la Fase 5 lo lee.

```
SESSION=none|indefinite|timed
SESSION_STARTED=<epoch o 0>
SESSION_ENDS=<epoch o 0>      # solo en sesiones por tiempo
BOOT_ID=<kern.bootsessionuuid>
STOP_AT=<epoch o 0>           # terminación pendiente
PASSES_USED=<n>
PASS_UNTIL=<epoch o 0>
```

- `BOOT_ID` sale de `sysctl -n kern.bootsessionuuid`, que cambia en cada arranque (verificado el 2026-10-28).
- **Se lee línea por línea con validación estricta**, igual que la configuración. Se escribe de forma atómica (temporal + `mv`) y **solo si cambió**: así `reconcile`, cada 30 s, no reescribe el archivo sin motivo.
- **(cambio) Estado dañado:** no detiene el motor. Se avisa, se registra y se empieza de nuevo como la primera vez (ver abajo).
- **(cambio) Primera vez (sin estado):** se toma el arranque actual y se **conserva lo que haya en hosts**: con bloque (por ejemplo, tras actualizar desde la Fase 1), una sesión sin fin; sin bloque, sin sesión. Así **instalar no activa ni quita el bloqueo**. Tratar "sin estado" como un arranque nuevo habría activado el bloqueo nada más instalar.
- **Candado:** dos llamadas a la vez (el LaunchDaemon y un atajo) podrían leer el mismo estado y pisarse al escribir. Los comandos que escriben toman un candado (`DATA_DIR/lock`) **antes de leer**. **(cambio)** Se usa `zsystem flock`, del módulo `zsh/system` que trae el zsh de macOS, en vez de `lockf`: sin procesos externos, y se suelta solo al terminar el proceso, también con error (verificado el 2026-10-29). Espera hasta 10 s. `status` no lo usa.
- **Notas de la Fase 1 que aplican aquí:** la primera línea `#!/bin/zsh -f`, la trampa de zsh con expansiones dentro de un `if`, y que el registro se lee con `/usr/bin/log`. **Trampa nueva:** un `=~` dentro de una función llamada pisa `$match` de quien la llamó (pasó en `state.zsh`; las pruebas lo detectaron).

## Módulos (regla D13)

Todos en `lib/`, con una responsabilidad cada uno; los más largos (`blocklist.zsh` y `session.zsh`) tienen 90 líneas.

| Archivo | Responsabilidad |
|---|---|
| `clock.zsh` | `NOW` y `BOOT_ID`, reales o falsos en pruebas; formato `HH:MM` |
| `config.zsh` | Leer la configuración línea por línea, sin `source` |
| `config-check.zsh` | Validar sus valores (rangos, `yes`/`no`, grupos) |
| `state.zsh` | Leer, validar y escribir el estado de forma atómica |
| `lock.zsh` | El candado (`zsystem flock`) |
| `session.zsh` | Crear, convertir y terminar sesiones, y aplicar el paso del tiempo (`session_advance`) |
| `engine.zsh` | El ciclo común de los comandos: empezar (candado, configuración, estado) y terminar (calcular hosts, guardar estado, escribir hosts, registrar) |
| `cmd-start.zsh`, `cmd-stop.zsh`, `cmd-cancel-stop.zsh`, `cmd-pass.zsh`, `cmd-status.zsh`, `cmd-reconcile.zsh` | Un archivo por subcomando |
| `status-json.zsh` | Salida JSON para la app |
| `cli.zsh` | Validar los argumentos y llamar al subcomando (antes estaba en `bin/guardian`) |

Cambios en módulos de la Fase 1:
- `blocklist_load` acepta grupos a omitir (los del pase en curso) y solo lee archivos normales (`*.txt(N.)`: ni enlaces ni FIFOs).
- `warn` y `err` (y por tanto `die`) también escriben en el registro siendo root: el LaunchDaemon no tiene terminal.
- La carpeta de datos se crea con `755`.
- `bin/guardian`, siendo root, comprueba además que `/usr/local/etc`, la carpeta de la configuración, la de las listas y el archivo de configuración sean solo de root y no sean enlaces. Si no, otro programa podría enlazarlos a un archivo privado y leerlo en los mensajes de error, o aflojar las reglas sin sudo.

**Cómo fluye un comando:** `engine_begin` → la lógica del comando cambia el estado en memoria → `engine_commit`. **hosts siempre se deriva del estado:** `engine_commit` calcula el hosts que corresponde y **todo lo que puede fallar falla antes de escribir nada**; luego guarda el estado y, por último, reescribe hosts si cambió. Si una escritura falla a medias, el siguiente `reconcile` lo arregla.

## Comandos

| Comando | ¿Root? | Comportamiento |
|---|---|---|
| `guardian start` | Sí | Sin sesión: crea una **indefinida** (`PASSES_USED=0`). Con sesión: no cambia nada, salvo que **cancela una terminación pendiente** ("sigo trabajando"). Es idempotente frente a dobles eventos de Atajos. |
| `guardian start <min>` | Sí | `<min>` debe estar en `TIMED_PRESETS`. Sin sesión: crea una **por tiempo**. Con una indefinida: la convierte (S2). Con otra por tiempo: error. |
| `guardian stop` | Sí | Sin sesión: nada. Por tiempo con `TIMED_LOCK=yes`: error "termina a las HH:MM". Con `STOP_DELAY_MINUTES=0`: termina ya. Si no: fija `STOP_AT = ahora + retraso`. Si ya había una terminación pendiente, no la alarga ni la acorta. |
| `guardian cancel-stop` | Sí | Borra `STOP_AT`: "seguir trabajando". |
| `guardian pass` | Sí | Requiere sesión, ningún pase en curso y `PASSES_USED < PASS_MAX_PER_SESSION`. Quita de hosts los grupos de `PASS_GROUPS`, fija `PASS_UNTIL` y suma 1 a `PASSES_USED`. Si no se cumple, error con un mensaje claro ("no quedan pases en esta sesión (3/3)"). Se puede usar durante una terminación pendiente. |
| `guardian status [--json]` | No | Texto para personas, o JSON para la app. **(cambio)** Muestra la sesión como la dejaría `reconcile` ahora mismo (si ya venció, dice que terminó), sin escribir nada; "Bloqueo" es lo que hay en hosts en ese instante. |
| `guardian reconcile` | Sí (solo lo llama el LaunchDaemon) | Ver abajo. Si no cambió nada, no escribe nada ni dice nada. |

- **Terminar una sesión:** quitar el bloque de hosts, `SESSION=none`, y poner a cero `SESSION_STARTED`, `SESSION_ENDS`, `STOP_AT`, `PASSES_USED` y `PASS_UNTIL`.
- **Todos los comandos aplican primero el paso del tiempo** (`session_advance`), no solo `reconcile`: así nunca actúan sobre una sesión que ya terminó.
- **(cambio) Listas dañadas con un bloque ya puesto:** el bloque se deja como está y se avisa, en vez de fallar. Si no, `stop` y `cancel-stop` serían imposibles con las listas dañadas (con el retraso, la sesión sigue y habría que reconstruir el bloque). Sin bloque puesto, `start` sí falla sin tocar nada.
- **Uso incorrecto** (argumentos que no existen, `start 025`, `start abc`): sale con 2 y muestra el uso.

`status --json` (todas las horas son epoch; 0 = no hay):

```json
{
  "now": 1800000060, "session": "timed", "session_started": 1800000000, "session_ends": 1800003000,
  "stop_at": 0, "pass_until": 1800000360, "passes_used": 1, "passes_max": 3, "pass_minutes": 5,
  "pass_groups": ["youtube"], "stop_delay_minutes": 5, "timed_lock": false,
  "timed_presets": [25, 50, 90], "autostart_at_boot": true, "blocking": true, "blocked_domains": 71
}
```
(La salida real tiene una clave por línea.)

## El paso del tiempo (`session_advance`) y `reconcile`

`reconcile` lo ejecuta un LaunchDaemon cada 30 s y al arrancar el Mac. En orden:

1. Si `STOP_AT > 0` y ya pasó, terminar la sesión.
2. Si la sesión es por tiempo y `SESSION_ENDS` ya pasó, terminarla.
3. Si `PASS_UNTIL > 0` y ya pasó, ponerlo a 0.
4. **¿Arranque nuevo?** (`BOOT_ID` guardado ≠ el actual)
   - Si la sesión es **indefinida**, se termina: "termina con el apagado".
   - Si es **por tiempo**, continúa: la hora es la del reloj, así que reiniciar no salta un candado.
   - Guardar el `BOOT_ID` nuevo.
   - Si queda sin sesión y `AUTOSTART_AT_BOOT=yes`, crear una **indefinida nueva** con el contador a 0.
5. **Aplicar:** el bloque deseado es "todos los grupos, menos `PASS_GROUPS` si hay un pase en curso", o ninguno si no hay sesión. Reescribir hosts **solo si es distinto**. Esto también restaura el bloque si alguien editó hosts a mano.

**(cambio)** El arranque nuevo va **después** de los vencimientos (en la especificación original iba primero). Si una sesión por tiempo venció con el Mac apagado, debe terminar antes de decidir el arranque automático; si no, ese día no habría sesión automática.

## LaunchDaemon

- **Archivo:** [launchd/com.efficiency-guardian.reconcile.plist](../../launchd/com.efficiency-guardian.reconcile.plist), instalado en `/Library/LaunchDaemons/` (`root:wheel 644`).
- **Contenido:** `ProgramArguments = [/usr/local/sbin/guardian, reconcile]`, `StartInterval = 30`, `RunAtLoad = true`.
- **Por qué así:** `WatchPaths` no es fiable ([02](../investigacion/02-integracion-macos.md#opciones)), y un `sleep` en segundo plano no sobrevive a un reposo ni a un reinicio.
- **Se carga** con `launchctl enable` + `launchctl bootstrap system <plist>` (con reintentos: justo después de un `bootout`, `bootstrap` a veces falla). Se descarga con `launchctl bootout system/com.efficiency-guardian.reconcile`.
- **Los avisos y errores** van al registro del sistema (siendo root, `warn`, `err` y los errores tempranos de `bin/guardian` usan `logger`): un `reconcile` que falla deja rastro. Con un error persistente (configuración rota), son unas 2 líneas por minuto hasta que se corrija.
- **Precisión:** los pases y los retrasos terminan con hasta 30 s de diferencia.

## Regla de sudoers

El instalador la genera a partir de `TIMED_PRESETS`. Solo argumentos exactos, sin comodines (en sudoers, un comando con argumentos solo admite esos argumentos exactos):

```
<usuario> ALL=(root) NOPASSWD: /usr/local/sbin/guardian start, /usr/local/sbin/guardian start 25, \
  /usr/local/sbin/guardian start 50, /usr/local/sbin/guardian start 90, /usr/local/sbin/guardian stop, \
  /usr/local/sbin/guardian cancel-stop, /usr/local/sbin/guardian pass
```

`status` no está (se usa sin sudo) y `reconcile` tampoco: solo lo ejecuta launchd como root.

## Instalador y desinstalador

**`install.sh`** (pasos nuevos o cambiados):
- **Paso 3 (nuevo):** valida la configuración (la instalada o, si no hay, `config.default`) contra las listas que se van a instalar, **antes de tocar nada**.
- **Paso 4:** descarga el LaunchDaemon antes de copiar, para que no ejecute una mezcla de versiones, y copia también el plist y la configuración (si no existe).
- **Paso 5:** la verificación de permisos incluye la configuración, `/Library/LaunchDaemons` y el plist. Si algo es inseguro, quita la regla de sudoers **y el LaunchDaemon**.
- **Paso 6:** las líneas manuales antiguas (el aviso ahora dice que tampoco funcionaría un pase).
- **Paso 7 (nuevo):** carga el LaunchDaemon. Va antes que la regla de sudoers para que, si la regla falla, el LaunchDaemon no quede descargado.
- **Paso 8:** regla de sudoers desde la configuración.
- Al final muestra `guardian status`.

**`uninstall.sh`:** comprueba primero que los marcadores de hosts estén sanos (si no, no toca nada). Después quita el LaunchDaemon **y la regla de sudoers** (así ni `reconcile` ni un atajo pueden volver a poner el bloque), toma el candado del motor (espera a un `guardian` en curso), **quita el bloque en el acto** (sin el retraso: desinstalar ya exige sudo) y borra el estado, el motor, los módulos y las listas. **Conserva** las copias de seguridad y la configuración del usuario.

**Ensayo sin root (2026-10-29):** con la misma técnica que en la Fase 1 (copia del repositorio apuntada a una carpeta temporal, con `install`, `chown`, `sudo`, `visudo`, `launchctl`, `logger`, `dscacheutil` y `killall` simulados). Funcionó todo:
- Instalación nueva con migración de las 4 líneas manuales.
- El motor instalado "como root": `reconcile`, `start`, `start 25`, `pass`, `stop` y `status`. Siendo root ignora `GUARDIAN_NOW`.
- Reinstalación con una sesión en curso y `TIMED_PRESETS` cambiado: conserva la configuración, regenera la regla y recarga el LaunchDaemon. La sesión sigue.
- Un módulo escribible por el grupo: el motor se niega a cargarlo, y el instalador quita la regla y el LaunchDaemon.
- Desinstalación con una terminación pendiente: quita el bloque en el acto y conserva la configuración y las copias.
- **Actualización desde la Fase 1** (commit `29b7ee0`) con el bloqueo activo: el bloqueo se conserva como sesión sin fin, y la carpeta de datos pasa de `700` a `755`.

**Segundo ensayo, tras la revisión:** instalación nueva; reinstalación con la configuración rota (se detiene en el paso 3 sin tocar nada: el LaunchDaemon sigue cargado y el motor intacto); configuración convertida en un enlace (el motor se niega a ejecutarse); desinstalación. Todo bien.

**Lo que no se pudo ensayar:** `launchctl` real (¿carga bien el plist? ¿hace falta el reintento?), `chown` real y la regla de sudoers en uso. Se comprueba en 4.4.

## Notificaciones

Las muestra **quien llama**, no el motor: el atajo o la app de la Fase 5. El motor corre como root y no puede notificar en la sesión del usuario.

Los avisos de tiempo (queda 1 min de pase, la sesión terminó) son trabajo de la app de la Fase 5.

## Huecos aceptados (conscientemente)

- **El usuario es administrador:** puede cambiar la hora del sistema, editar la configuración con sudo o desinstalar. El objetivo es fricción, no seguridad.
- **Con `AUTOSTART_AT_BOOT=no`, reiniciar termina una sesión indefinida sin esperar el retraso.** Con el valor por defecto (`yes`), reiniciar no sirve para desbloquear: arranca otra.
- **Reiniciar sí reinicia el contador de pases** (con el arranque automático, la sesión nueva empieza en 0). Cuesta un reinicio completo, así que se acepta.
- **`stop` → esperar el retraso → `start` reinicia el contador de pases.** Cuesta 5 minutos, así que se acepta.
- **(nuevo) Un comando rechazado no escribe nada**, ni siquiera el paso del tiempo. Por ejemplo, si un pase venció y se pide otro sin que queden, el pase vencido se vuelve a bloquear en el siguiente `reconcile` (hasta 30 s después), no en ese instante.
- **(nuevo) Listas que se dañan durante un pase:** al vencer el pase, el bloque se deja como estaba (sin YouTube) hasta que se corrijan las listas. Dañarlas exige sudo y el instalador las valida, así que se acepta.
- **(nuevo) `launchctl bootout` durante un `reconcile`** lo interrumpe: podría quedar un temporal `.hosts.guardian.*` en `/etc` o `.state.*` en la carpeta de datos. Inofensivo; se borra a mano.
- **(nuevo) Las líneas manuales antiguas de hosts** (las 4 de YouTube) bloquean fuera del bloque gestionado: si el usuario no las quita al instalar, **un pase no desbloquea YouTube**. El instalador ofrece quitarlas (paso 6).

## Pruebas

Sin root, como en la Fase 1 (`zsh tests/run.zsh`). Variables solo para pruebas, ignoradas siendo root: `GUARDIAN_NOW` (reloj falso), `GUARDIAN_BOOT_ID` (arranque falso), `GUARDIAN_CONFIG` y, como en la Fase 1, `GUARDIAN_DATA_DIR` (donde vive el estado). **(cambio)** No hay `GUARDIAN_STATE_DIR`: el estado está en la carpeta de datos.

| Archivo | Qué prueba |
|---|---|
| `test-config.zsh` | `config.default` coincide con el código; valores válidos e inválidos; nada se ejecuta (`$(…)`, comillas invertidas, subíndices aritméticos) |
| `test-state.zsh` | Formato, permisos, escritura atómica, sin reescribir si no cambia, estado dañado |
| `test-sessions.zsh` | `start`, `start <min>`, fuera de `TIMED_PRESETS`, S2 (conversión, rechazo, no salta el retraso) |
| `test-stop.zsh` | Retraso al terminar, `cancel-stop`, `start` durante la espera, candado |
| `test-pass.zsh` | Pase: qué grupos quita, vencimiento, límites, durante una terminación pendiente |
| `test-pass-config.zsh` | Pase con listas dañadas (no se gasta), sin pases, varios grupos, contador de una sesión nueva |
| `test-reconcile.zsh` | Arranques, arranque automático, primera vez sin estado, actualización desde la Fase 1, estado dañado, hosts editado a mano, sin cambios no escribe |
| `test-status.zsh` | Texto y JSON (leído con `plutil`, que lo valida) |
| `test-lock.zsh` | Un comando espera al otro; `status` no espera |
| `test-install.zsh` | Regla de sudoers desde la configuración, plist del LaunchDaemon, rutas |

Los casos mínimos de la especificación original están todos cubiertos.

## Verificación manual tras instalar (4.4, la hace el usuario)

Además de la [verificación de la Fase 1](fase-1-motor.md#verificación-manual-tras-instalar-la-hace-el-usuario):

> **2026-10-29: el usuario cerró esta verificación en parte.** Las casillas sin marcar no se probaron: se descubrirán con el uso diario.

- [x] `sudo launchctl print system/com.efficiency-guardian.reconcile` muestra el trabajo cargado, con `run interval = 30 seconds`. (2026-10-29: funciona sin sudo; 57 ejecuciones en 28 min, todas con salida 0.)
- [ ] `sudo -n /usr/local/sbin/guardian start 25` funciona sin contraseña, y `sudo -n /usr/local/sbin/guardian start 37` la pide o falla.
- [x] **Retraso:** `sudo -n guardian stop` → `guardian status` dice "Terminación pendiente". A los 5 min (más hasta 30 s), YouTube vuelve a cargar sin hacer nada más. (2026-10-29: `stop` a las 12:36:26, fin a las 12:41:39.)
- [ ] **Seguir trabajando:** `stop` y luego `sudo -n guardian cancel-stop` → a los 6 min sigue bloqueado. (2026-10-29: `cancel-stop` respondió "Terminación cancelada: la sesión sigue" y `status` lo confirmó, pero no se esperaron los 6 min: el usuario volvió a pedir `stop` al momento.)
- [x] **Pase:** `sudo -n guardian pass` → YouTube carga (quizá haya que recargar); Facebook no. A los 5 min, una pestaña nueva de YouTube no carga (la abierta puede seguir: Fase 3). (2026-10-29, Brave: YouTube cargó y WhatsApp Web no. El pase venció a las 12:17:45 y `reconcile` volvió a bloquear a las 12:17:59. No se probó expresamente iniciar sesión en YouTube Studio durante el pase, pero `www.youtube.com` cargaba, que es lo que bloqueaba ese inicio de sesión.)
- [ ] **Reposo:** con una sesión de 25 min, cerrar la tapa 30 min. Al abrir, ¿cuánto tarda en desbloquearse? (¿launchd ejecuta el trabajo pendiente al despertar?)
- [ ] **Reposo largo (una noche sin apagar):** antes, anotar `sysctl -n kern.bootsessionuuid` y la hora de inicio de `guardian status`. Al despertar, ¿son iguales? Si el identificador cambiara al despertar de un reposo profundo, la sesión sin fin terminaría con cada reposo (sin verificar; lo señaló la revisión).
- [ ] **Reinicio:** con una sesión sin fin, reiniciar. Al entrar, `guardian status` muestra una sesión **nueva** (hora de inicio de ahora, pases 0 de 3). ¿Cuánto tarda en aparecer?
- [ ] **Candado (opcional):** poner `TIMED_LOCK=yes` con sudo, `start 25` y `stop` → rechazado con la hora de fin. Volver a `no`.
- [x] El registro muestra los eventos (start, pass, fin del pase, stop, cancel-stop y fin de la sesión): `/usr/bin/log show --last 1h --style compact --predicate 'process == "logger" AND eventMessage BEGINSWITH "efficiency-guardian"'`.

Anota los resultados en la bitácora de [PLAN.md](../../PLAN.md).

### Fallos encontrados en la verificación manual (sin arreglar)

- **2026-10-29 · La pista de `stop` no se puede ejecutar tal cual.** `stop` dice "Para seguir trabajando: guardian cancel-stop." ([lib/cmd-stop.zsh](../../lib/cmd-stop.zsh)). El usuario lo escribió y obtuvo `zsh: command not found: guardian`: `/usr/local/sbin` no está en el PATH del usuario (`/etc/paths` de macOS no lo incluye), y además hace falta `sudo -n`. Lo que funciona es `sudo -n /usr/local/sbin/guardian cancel-stop`. Es el único mensaje del motor que sugiere un comando. Arreglo posible: escribir el comando completo en el mensaje. Esperar a la app (5.6): con ella casi nadie escribirá comandos.

## Medir para ajustar (4.5)

Cada pase, inicio, terminación, error y cambio de hosts queda registrado con `logger`. Tras 1–2 semanas, revisar los registros para saber si 5 min × 3 pases y 5 min de retraso son los valores correctos:
```
/usr/bin/log show --last 7d --style compact --predicate 'process == "logger" AND eventMessage BEGINSWITH "efficiency-guardian"'
```
