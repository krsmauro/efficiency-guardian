# Investigación: el interruptor y los permisos en macOS

> Investigado el 2026-10-28 (macOS 27.0). Confianza: **alta** = documentación de Apple, `man` local o código; **media** = comunidad; **baja** = un solo reporte o inferencia.

## Resumen

- **Interruptor recomendado:**
  - Un modo de Concentración nativo (por ejemplo "Trabajo profundo") y **automatizaciones de Atajos** (Shortcuts): "al activarse/desactivarse", que llegaron al Mac en **macOS 26**.
  - El usuario sigue usando el mismo botón de Concentración que ya conoce, y el ícono de la barra de menús indica si está activo.
- **Permisos:** una regla en `/etc/sudoers.d/` permite ejecutar **un solo script de root con argumentos exactos** sin contraseña.
- **Swift:** solo hace falta si se quiere una app con estado visible propio (barra de menús o Centro de control). Es una fase opcional.

## Automatizaciones de Atajos en el Mac

- **Llegaron en macOS 26 Tahoe** (Sonoma no las tenía) (confianza alta).
  - Disparador: "Cuando <Concentración> se activa / se desactiva / ambas".
  - Modos de ejecución: **"Ejecutar de inmediato"** o "Ejecutar tras confirmación".
  - Fuentes: [Apple 125148](https://support.apple.com/en-gb/125148), [MacStories](https://www.macstories.net/stories/macos-26-tahoe-the-macstories-review/4), [MacMost](https://macmost.com/an-introduction-to-shortcuts-automation-in-macos-tahoe.html).
- **Fiabilidad sin confirmar en el Mac** (hay que probarla en la Fase 2):
  - ¿Se dispara si la Concentración se activa desde el iPhone (compartida entre dispositivos)?
  - ¿Se dispara si la activa un horario?
  - ¿Se dispara si el Mac estaba en reposo?
  - En **iOS** hay reportes de que el cambio por horario dispara un evento "off" y luego otro "on" ([Keyboard Maestro forum](https://forum.keyboardmaestro.com/t/is-there-a-better-way-to-trigger-automatic-changes-based-on-current-focus-mode-v10-2/36676)).
  - **Consecuencia de diseño:** el script debe ser **idempotente**. Ejecutar `start` dos veces da el mismo resultado, y un evento duplicado no hace daño.
- macOS 27 no cambió los disparadores de Concentración (las novedades de WWDC26 son disparadores de capturas, teclado y notificaciones).

## La acción "Ejecutar script de shell"

- **Ajuste necesario:** Atajos → Ajustes → Avanzado → **"Permitir ejecutar scripts"** (confianza alta).
- **Entorno:** el script corre como **el usuario**, no como root, con un PATH mínimo y sin leer `~/.zshrc`. Hay que usar **rutas absolutas**.
- **`sudo -n /ruta/script on` funciona con una regla NOPASSWD.**
  - `requiretty` está desactivado por defecto (verificado en `man sudoers` de esta Mac, sudo 1.9.17p2).
  - `-n` hace que falle de inmediato en vez de quedarse esperando una contraseña.
- **Riesgo conocido:** en un hilo de 2023, un atajo fallaba con "Operation not permitted" al ejecutarse desde la barra de menús pero no dentro de la app. Probarlo.
- **Alternativa descartada:** AppleScript `do shell script … with administrator privileges` **pide contraseña** (la recuerda 5 minutos). No sirve para un clic.

## Centro de control (macOS 26/27)

- **Se puede añadir un atajo como control:** "Ejecutar atajo" en "Editar controles". También se puede **llevar a la barra de menús** (confianza alta).
- **Un control de atajo es solo un botón: no muestra encendido/apagado** (confianza media‑alta).
- **Concentración específica como interruptor propio: no confirmado** (confianza baja).
  - El control de Concentración es el módulo completo y elegir uno concreto toma dos clics.
  - La barra de menús sí puede mostrar el ícono de Concentración "cuando está activo", y eso sirve de **indicador de estado**.
- **Truco para un clic:** un atajo con la acción "Definir Concentración → Alternar 'Trabajo profundo'" colocado como botón en el Centro de control. Eso dispara las automatizaciones. **Verificar** que la opción "Alternar" exista en el Mac.
- **Error conocido** (sep. 2025): los controles de terceros desaparecían del Centro de control; se recuperaban abriendo la galería de widgets ([MacStories](https://www.macstories.net/stories/mystery-solved-why-third-party-apps-vanished-from-the-macs-control-center/)).

## Si algún día hay app propia en Swift (fase opcional)

> **Actualización 2026-10-28:** ya no es opcional. El usuario eligió una app de barra de menús en Swift como interfaz de la v1 (D12, [Fase 5](../fases/fase-5-app-barra-de-menus.md)). El título de esta sección se mantiene para no romper los enlaces.

Swift es **el único lenguaje con una ventaja enorme aquí**, pero **solo para la interfaz nativa**. El motor de bloqueo no lo necesita.

| Opción | Qué da | Requisitos y riesgos |
|---|---|---|
| **`MenuBarExtra` (app de barra de menús)** | Un clic **con estado visible** (ícono lleno o vacío). Es lo más simple. | App sin sandbox que llama `sudo -n /usr/local/sbin/guardian start`. **No necesita helper privilegiado.** |
| **`ControlWidgetToggle` (interruptor en el Centro de control)** | Interruptor con estado dentro del Centro de control. | macOS 26+. App + extensión de widget **con sandbox**, App Group compartido y `SetValueIntent`. La intención corre en la extensión con sandbox, así que necesita un puente hacia la app. Con firma "Personal Team" (Apple ID gratis) **no está confirmado que funcione**: hacer un prototipo desechable primero. |
| **Focus Filters (`SetFocusFilterIntent`)** | La app se entera de que se activó una Concentración, sin Atajos. | **Poco fiable en el Mac:** reportes de que `perform()` nunca se llama, el más reciente en mayo de 2026 con macOS 26.5 ([foro Apple](https://developer.apple.com/forums/thread/826766)). No basar nada en esto. |
| **`SMAppService.daemon` (helper privilegiado)** | Un servicio root registrado por la app. | Requiere que la app y el helper estén firmados con la misma identidad de Apple. **La firma ad‑hoc lo rompe** ([foro Apple](https://developer.apple.com/forums/thread/802443)). Innecesario si se usa la regla sudoers. |

## Cómo dar permisos de root sin contraseña

### Opciones

1. **Regla en `/etc/sudoers.d/` (elegida para v1):** simple y síncrona (el atajo ve si falló), sin firma de código.
2. **LaunchDaemon** en `/Library/LaunchDaemons`: un servicio root que corre siempre. **Útil para la Fase 4** (volver a bloquear al terminar un pase temporal, aunque el Mac duerma).
   - `man launchd.plist` dice que `WatchPaths` está "highly discouraged" porque se pueden perder cambios. Mejor `StartInterval` (cada N segundos) + `RunAtLoad`, y en cada ejecución **reconciliar el estado completo**.
   - Desde Ventura aparece en Ajustes → Ítems de inicio y el usuario lo puede apagar.
3. **`SMAppService`:** solo con app Swift firmada (ver tabla arriba).

### Reglas para la regla de sudoers (confianza alta, `man sudoers` local)

- **Nombre del archivo:** `/etc/sudoers.d/efficiency-guardian`, **sin punto en el nombre**. sudo ignora en silencio los archivos con `.` o que terminan en `~`.
- **Permisos:** dueño `root:wheel`, modo **0440**.
- **Validar antes de instalar:** `visudo -c -f archivo_temporal`, y después `visudo -c`. Un error de sintaxis puede dejar sudo inutilizable.
  - Rescate si pasa: AppleScript `with administrator privileges`, que no usa sudo.
- **Argumentos exactos, sin comodines:**
  ```
  mauro ALL=(root) NOPASSWD: /usr/local/sbin/guardian start, /usr/local/sbin/guardian stop
  ```
- **El script y todas las carpetas de su ruta deben ser de root y no escribibles por el usuario.**
  - Si no, cualquier proceso del usuario (incluido malware) podría reemplazar el script y obtener root sin contraseña.
  - Verificado: `/usr/local` es `root:wheel 755`; `/usr/local/sbin` no existe y lo crea el instalador.
- **Nunca apuntar sudoers a `node` o `python`:**
  - Los de `~/.nvm` y `/opt/homebrew` son propiedad del usuario, así que se pueden reemplazar.
  - Un intérprete con `-c` o `-e` ejecuta cualquier código, así que esa regla equivale a dar una terminal root.
- **Higiene del script:**
  - PATH explícito.
  - La lista de dominios en un archivo de root.
  - Escritura **atómica** de `/etc/hosts`: archivo temporal en `/etc` y luego `mv`.
  - Vaciar la caché DNS al final.

## Por qué el motor es un script `zsh` y no TypeScript o Python

1. **Corre como root**, así que su intérprete debe ser del sistema y no modificable por el usuario. `/bin/zsh` lo es; el `node` de nvm y el `python3` de Homebrew no.
2. **Cero dependencias:** sigue funcionando aunque se actualice Node o Python, o cambie la versión activa de nvm.
3. **Es pequeño**: leer una lista, reescribir un bloque de texto y vaciar la caché DNS. No hay lógica que justifique otro lenguaje. Va repartido en módulos de unas 100 líneas como máximo (regla D13).
4. TypeScript tendría sentido si más adelante hubiera una extensión de navegador. Swift, si hubiera una app nativa.
