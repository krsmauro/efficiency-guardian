# Fase 4: sesiones, tiempo y pases

> Borrador de especificación (2026-10-28), con los requisitos del usuario todavía frescos. Requiere las Fases 1 y 2. Conviene tener la [Fase 3](fase-3-cerrar-pestanas.md): sin ella, una pestaña abierta sigue reproduciendo cuando vence un pase o termina una sesión.

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

## Supuestos que tomé y el usuario debe confirmar

- **S1:** el retraso al terminar se aplica a **todas** las sesiones, también a la indefinida y a "desactivar la Concentración". El motivo del usuario ("darle tiempo de desistir") aplica igual. Para excluir la indefinida bastaría otra clave en la configuración.
- **S2:** si hay una sesión indefinida en curso (algo habitual, con el arranque automático) y se pide una **por tiempo**, la indefinida **se convierte** en una por tiempo que termina dentro de N minutos.
  - **Conserva el contador de pases**, para que no sirva para reiniciarlos.
  - Si se pidiera una por tiempo con otra por tiempo ya en curso, se rechaza: no se puede acortar una sesión con candado.
- **S3 (punto débil detectado):** un MacBook casi nunca se apaga: al cerrar la tapa **duerme**. Una sesión indefinida que "termina al apagar" puede durar **días**, y "3 pases por sesión" se convertiría en 3 pases por semana.
  - **Propuesta:** en las sesiones indefinidas, el contador de pases **se reinicia cada día** a una hora configurable (`PASS_RESET_HOUR=4`, las 4 a. m.). La sesión sigue siendo la misma.
  - Alternativa: que la sesión indefinida termine también a esa hora y arranque otra.
  - Confirmar con el usuario antes de implementar.

## Configuración: `/usr/local/etc/efficiency-guardian/config` (`root:wheel 644`)

```
# Sesiones por tiempo: duraciones ofrecidas, en minutos (cada una entre 1 y 480)
TIMED_PRESETS=25,50,90
# Candado completo: yes = una sesión por tiempo no se puede terminar antes de la hora
TIMED_LOCK=no
# Retraso al pedir terminar, en minutos (0 = inmediato; máximo 60)
STOP_DELAY_MINUTES=5
# Sesión indefinida automática al encender el Mac
AUTOSTART_AT_BOOT=yes
# Pases
PASS_MINUTES=5
PASS_MAX_PER_SESSION=3
PASS_GROUPS=youtube
```

- **Se lee línea por línea con validación estricta:** números enteros dentro de rango, `yes`/`no`, grupos que existen en `blocklists/`.
- **Nunca usar `source` sobre ese archivo:** ejecutaría su contenido como código root.
- Cambiar la configuración requiere `sudo`. Es fricción deseada: aflojar las reglas en un momento de debilidad cuesta un paso más.
- El repositorio trae `config.default`, y el instalador la copia solo si no existe.
- **Si se cambia `TIMED_PRESETS`, hay que volver a ejecutar el instalador,** que regenera la regla de sudoers (ver abajo).

## Estado: `/var/db/efficiency-guardian/state` (`root:wheel 644`)

La carpeta pasa a ser `755` y las copias de seguridad quedan en `600`. El estado debe ser legible sin root, porque la app de la Fase 5 lo lee.

```
SESSION=none|indefinite|timed
SESSION_STARTED=<epoch>
SESSION_ENDS=<epoch o 0>      # solo en sesiones por tiempo
BOOT_ID=<kern.bootsessionuuid>
STOP_AT=<epoch o 0>           # terminación pendiente
PASSES_USED=<n>
PASS_UNTIL=<epoch o 0>
```

- `BOOT_ID` sale de `sysctl -n kern.bootsessionuuid`, que cambia en cada arranque (verificado el 2026-10-28). Sirve para saber que el Mac **se apagó o reinició**.
- Escribir el estado de forma atómica (temporal + `mv`), igual que hosts.
- **Dos llamadas a la vez** (el LaunchDaemon cada 30 s y un atajo o la app) pueden leer el mismo estado y pisarse al escribir (por ejemplo, perder un pase contado). Hace falta un candado alrededor de "leer, decidir, escribir": `/usr/bin/lockf` o `/usr/bin/shlock`, ambos en macOS (verificado el 2026-10-29). En la Fase 1 no hacía falta: dos `start` a la vez escriben exactamente lo mismo.
- **Notas de la Fase 1 que aplican aquí** (ver [fase 1](fase-1-motor.md)): la primera línea `#!/bin/zsh -f`, la trampa de zsh con expansiones dentro de un `if`, y que el registro se lee con `/usr/bin/log` (no `log`).

## Módulos nuevos (regla D13: una responsabilidad y unas 100 líneas como máximo por archivo)

| Archivo | Responsabilidad |
|---|---|
| `lib/config.zsh` | Leer y validar la configuración, sin `source` |
| `lib/state.zsh` | Leer y escribir el estado de forma atómica |
| `lib/clock.zsh` | Hora actual y `BOOT_ID`, reales o falsos en pruebas |
| `lib/session.zsh` | Crear, convertir y terminar sesiones |
| `lib/cmd-start.zsh`, `lib/cmd-stop.zsh`, `lib/cmd-cancel-stop.zsh`, `lib/cmd-pass.zsh`, `lib/cmd-status.zsh`, `lib/cmd-reconcile.zsh` | Un archivo por subcomando |
| `lib/status-json.zsh` | Salida JSON para la app (separada del texto para personas) |
| `install/launchdaemon.zsh` | Instalar y cargar el LaunchDaemon |
| `tests/test-<módulo>.zsh` | Un archivo de pruebas por módulo |

El paso 5 de `reconcile` ("aplicar") es lógica compartida y vive en `lib/session.zsh` o en su propio `lib/apply.zsh` si no cabe.

## Comandos

| Comando | ¿Root? | Comportamiento |
|---|---|---|
| `guardian start` | Sí | Sin sesión: crea una **indefinida** (`PASSES_USED=0`). Con sesión: no cambia nada, salvo que **cancela una terminación pendiente** ("sigo trabajando"). Es idempotente frente a dobles eventos de Atajos. |
| `guardian start <min>` | Sí | `<min>` debe estar en `TIMED_PRESETS`. Sin sesión: crea una **por tiempo**. Con una indefinida: la convierte (S2). Con otra por tiempo: error. |
| `guardian stop` | Sí | Sin sesión: nada. Por tiempo con `TIMED_LOCK=yes`: error "termina a las HH:MM". Con `STOP_DELAY_MINUTES=0`: termina ya. Si no: fija `STOP_AT = ahora + retraso`. Si ya había una terminación pendiente, no la alarga ni la acorta. |
| `guardian cancel-stop` | Sí | Borra `STOP_AT`: "seguir trabajando". |
| `guardian pass` | Sí | Requiere sesión, ningún pase en curso y `PASSES_USED < PASS_MAX_PER_SESSION`. Quita de hosts los grupos de `PASS_GROUPS`, fija `PASS_UNTIL` y suma 1 a `PASSES_USED`. Si no se cumple, error con un mensaje claro ("No quedan pases en esta sesión (3/3)"). Se puede usar durante una terminación pendiente. |
| `guardian status [--json]` | No | Texto para personas, o JSON para la app. Incluye tipo de sesión, hora de fin, terminación pendiente, pase en curso y pases restantes. |
| `guardian reconcile` | Sí (solo lo llama el LaunchDaemon) | Ver el algoritmo de abajo. |

**Terminar una sesión** (pasos comunes): quitar el bloque de hosts, `SESSION=none`, y poner a cero `STOP_AT`, `PASS_UNTIL` y `SESSION_ENDS`.

## `reconcile`: el corazón del tiempo

Lo ejecuta un LaunchDaemon cada 30 s y al arrancar el Mac. En orden:

1. **¿Arranque nuevo?** (`BOOT_ID` guardado ≠ el actual)
   - Si la sesión era **indefinida**, se termina: "termina con el apagado".
   - Si era **por tiempo**, **continúa** si `SESSION_ENDS` aún no ha pasado. La hora es la del reloj, así que reiniciar no salta un candado.
   - Guardar el `BOOT_ID` nuevo.
   - Si queda sin sesión y `AUTOSTART_AT_BOOT=yes`, crear una **indefinida nueva** con el contador a 0.
2. Si `STOP_AT > 0` y ya pasó, terminar la sesión.
3. Si la sesión es por tiempo y `SESSION_ENDS` ya pasó, terminarla.
4. Si `PASS_UNTIL > 0` y ya pasó, ponerlo a 0.
5. **Aplicar:** el bloque deseado es "todos los grupos, menos `PASS_GROUPS` si hay un pase en curso", o vacío si no hay sesión. Reescribir hosts **solo si es distinto**. Esto también restaura el bloque si alguien editó hosts a mano.

## LaunchDaemon

- **Archivo:** `/Library/LaunchDaemons/com.efficiency-guardian.reconcile.plist` (`root:wheel 644`).
- **Contenido:** `ProgramArguments = [/usr/local/sbin/guardian, reconcile]`, `StartInterval = 30`, `RunAtLoad = true`.
- **Por qué así:** `WatchPaths` no es fiable ([02](../investigacion/02-integracion-macos.md#opciones)), y un `sleep` en segundo plano no sobrevive a un reposo ni a un reinicio.
- **Precisión:** los pases y los retrasos terminan con hasta 30 s de diferencia.
- **Verificar:**
  - Tras despertar el Mac, ¿launchd ejecuta el trabajo pendiente enseguida?
  - Tras arrancar, ¿cuánto tarda en aplicar el arranque automático?

## Regla de sudoers

El instalador la genera a partir de la configuración. Solo argumentos exactos, sin comodines:

```
<usuario> ALL=(root) NOPASSWD: /usr/local/sbin/guardian start, \
  /usr/local/sbin/guardian start 25, /usr/local/sbin/guardian start 50, /usr/local/sbin/guardian start 90, \
  /usr/local/sbin/guardian stop, /usr/local/sbin/guardian cancel-stop, /usr/local/sbin/guardian pass
```

`reconcile` **no** está en la regla: solo lo ejecuta launchd como root.

## Notificaciones

Las muestra **quien llama**, no el motor: el atajo o la app de la Fase 5. El motor corre como root y no puede notificar en la sesión del usuario.

Los avisos de tiempo (queda 1 min de pase, la sesión terminó) son trabajo de la app de la Fase 5.

## Huecos aceptados (conscientemente)

- **El usuario es administrador:** puede cambiar la hora del sistema, editar la configuración con sudo o desinstalar. El objetivo es fricción, no seguridad.
- **Con `AUTOSTART_AT_BOOT=no`, reiniciar termina una sesión indefinida sin esperar el retraso.** Con el valor por defecto (`yes`), reiniciar no sirve de atajo: arranca otra.
- **`stop` → esperar el retraso → `start` reinicia el contador de pases.** Cuesta 5 minutos, así que se acepta.

## Pruebas (extender `tests/run.zsh`)

Sin root, como en la Fase 1. Variables solo para pruebas, ignoradas si se ejecuta como root: `GUARDIAN_NOW` (reloj falso), `GUARDIAN_BOOT_ID`, `GUARDIAN_STATE_DIR` y `GUARDIAN_CONFIG`.

**Casos mínimos:**
- `start` crea una indefinida; un segundo `start` no reinicia el contador.
- `start 50` sin sesión crea una por tiempo; `reconcile` en el minuto 49 no hace nada; en el 50, termina.
- `start 37` (fuera de `TIMED_PRESETS`) produce error.
- **Retraso al terminar:**
  - `stop` deja la terminación pendiente.
  - `reconcile` a los 4 min no termina; a los 5, sí.
  - `cancel-stop` la anula.
  - `start` durante la espera también la anula.
- `TIMED_LOCK=yes`: `stop` es rechazado, pero el pase funciona.
- **Arranque:**
  - Un `BOOT_ID` nuevo termina la indefinida y, con arranque automático, crea otra con el contador a 0.
  - La sesión por tiempo sobrevive si no ha vencido.
- **Pases:**
  - El pase quita solo `PASS_GROUPS` y vuelve al vencer.
  - El 4.º es rechazado.
  - Sin sesión, es rechazado.
- S2: convertir una indefinida en una por tiempo conserva `PASSES_USED`.
- Una configuración inválida (`PASS_MINUTES=abc`, `PASS_GROUPS=noexiste`, `STOP_DELAY_MINUTES=$(rm …)`) produce error sin ejecutar nada.
- Si hosts fue editado a mano dentro de una sesión, `reconcile` lo restaura.

## Medir para ajustar

Cada pase, inicio y terminación queda registrado con `logger -t efficiency-guardian`. Tras 1–2 semanas, revisar los registros para saber si 5 min × 3 pases y 5 min de retraso son los valores correctos:
```
/usr/bin/log show --last 7d --style compact --predicate 'process == "logger" AND eventMessage BEGINSWITH "efficiency-guardian"'
```
