# Fase 3: cerrar las pestañas de sitios bloqueados

> Borrador de especificación (2026-10-28). Requiere la Fase 1. Contexto: [01-metodos-de-bloqueo.md](../investigacion/01-metodos-de-bloqueo.md#cuándo-hace-efecto-el-bloqueo-confianza-mediaalta).

## Problema

Cambiar `/etc/hosts` bloquea las visitas **nuevas**, pero una pestaña de YouTube ya abierta **sigue reproduciendo**. Chromium mantiene vivas las conexiones existentes, y el video viene de servidores `*.googlevideo.com` con nombres aleatorios que no se pueden listar. Pasa en tres momentos:

1. Al **iniciar** una sesión con YouTube abierto.
2. Al **vencer un pase** (Fase 4): sin esta fase, un pase de 5 minutos dura lo que dure la pestaña.
3. Al **reiniciar** el bloqueo tras una terminación cancelada.

## Objetivo

Mientras haya dominios bloqueados, cerrar en ≤15 s las pestañas abiertas de esos dominios en Safari, Chrome, Brave, Vivaldi y Thorium. No debe abrir navegadores que estén cerrados ni tocar ninguna otra pestaña.

## Diseño

### Fuente de verdad: el bloque gestionado de `/etc/hosts`

- `/etc/hosts` es legible por cualquier usuario, así que no hace falta root.
- Los dominios bloqueados **ahora mismo** son los nombres dentro del bloque `# >>> efficiency-guardian`.
- Así se respetan solos los pases de la Fase 4: los grupos con pase no están en el bloque, así que sus pestañas no se cierran.
- La comparación es por **nombre exacto** del host, igual que hace hosts. Por ejemplo `studio.youtube.com` no está en la lista, así que no se cierra.

### Script `close-tabs`

- **Ruta instalada:** la carpeta `/usr/local/libexec/efficiency-guardian/close-tabs/` (`root:wheel`, carpeta `755` y archivos `644`; el `.zsh`, `755`). Corre como el **usuario**, sin sudo.
- **Archivos (regla D13: una responsabilidad y unas 100 líneas como máximo por archivo):**
  - `close-tabs/close-tabs.zsh`: lee el bloque de hosts y llama a cada navegador abierto. Reutiliza `lib/hosts-block.zsh` de la Fase 1 para leer el bloque.
  - `close-tabs/chromium.js`: JXA común a Chrome, Brave, Vivaldi y Thorium; recibe el bundle ID.
  - `close-tabs/safari.js`: JXA para Safari.
  - `close-tabs/match.js`: extrae el host de una URL y decide si cerrar. Separado para poder probarlo solo.
- **Pasos:**
  1. Leer el bloque de hosts y obtener la lista de dominios. Si está vacía, salir.
  2. Por cada navegador **que ya esté abierto**, ejecutar un script **JXA** (JavaScript for Automation: `osascript -l JavaScript`) que recorra ventanas y pestañas, extraiga el host de cada URL y cierre las que coincidan.
     - JXA en vez de AppleScript, porque el usuario conoce JavaScript.
     - Para saber si un navegador está abierto: `Application("…").running()` o `pgrep`. **Nunca** llamar a una app que no esté abierta, porque eso la abriría.
  3. Registrar con `logger -t efficiency-guardian "close-tabs: N pestañas"`.
- **Navegadores** (identificadores verificados el 2026-10-28; los 4 Chromium traen diccionario AppleScript, `scripting.sdef`):

| Navegador | Bundle ID | Notas |
|---|---|---|
| Safari | `com.apple.Safari` | `tabs` y `URL` de cada ventana |
| Chrome | `com.google.Chrome` | `windows[].tabs[].url()`, `close()` |
| Brave | `com.brave.Browser` | Igual que Chrome |
| Vivaldi | `com.vivaldi.Vivaldi` | Igual que Chrome (verificar) |
| Thorium | `org.chromium.Thorium` | Igual que Chrome (verificar) |

- **No hace falta** activar "Permitir JavaScript desde Apple Events" en los navegadores. Eso solo se necesita para ejecutar JS **dentro** de las páginas; aquí solo se leen URLs y se cierran pestañas.

### Disparador: LaunchAgent de usuario

- **Archivo:** `~/Library/LaunchAgents/com.efficiency-guardian.close-tabs.plist`.
- **Contenido:** `ProgramArguments = [/usr/local/libexec/efficiency-guardian/close-tabs/close-tabs.zsh]`, `StartInterval = 15`, `RunAtLoad = true`.
- **Coste:** cuando no hay bloqueo, el script sale de inmediato tras leer hosts.
- **Cuando exista la app (Fase 5):** puede reemplazar este agente. La app ya está siempre abierta, puede cerrar pestañas **en el instante** en que cambia el estado y tendría su propio permiso de Automatización. Decidirlo en la Fase 5.

## Riesgos a verificar primero (prototipo de 10 minutos antes de implementar)

1. **Permisos de Automatización (TCC):** la primera vez, macOS pide permiso para "controlar Brave" y los demás.
   - Con procesos en segundo plano (LaunchAgent → `osascript`), el aviso **puede no aparecer** y el script falla en silencio (error `-1743`).
   - Probar si aparece y a quién se atribuye: osascript, el script o Terminal.
   - **Alternativa** si falla: ejecutar `close-tabs` desde el atajo justo después de `start` (el permiso queda a nombre de Atajos), o esperar a la app de la Fase 5.
2. **Ventanas privadas o de incógnito:** ¿JXA ve sus pestañas?
3. **Conexiones reutilizadas:** tras cerrar la pestaña, ¿una pestaña nueva de youtube.com carga durante unos segundos gracias a una conexión que sigue abierta? Si pasa, documentarlo. La opción manual es `chrome://net-internals/#sockets` → "Flush socket pools".

## Pruebas

- **Automáticas** (`tests/`, sin navegadores): la función que extrae el host de una URL y decide si cerrar. Casos:
  - `https://www.youtube.com/watch?v=…` → cerrar.
  - `https://studio.youtube.com/…` → no cerrar.
  - `https://www.linkedin.com/…` → no cerrar.
  - `https://user@www.youtube.com:443/…` → cerrar.
  - `chrome://settings` → no cerrar.
  - Una URL vacía → no cerrar.
- **Manuales** (el usuario), en cada navegador:
  - [ ] Un video de YouTube reproduciéndose + `start` → la pestaña se cierra en ≤15 s.
  - [ ] Las pestañas de LinkedIn y YouTube Studio siguen abiertas.
  - [ ] Con el navegador cerrado, no se abre solo.
  - [ ] (Con la Fase 4) Con un pase en curso, YouTube no se cierra; al vencer, sí.

## Opción a decidir en la Fase 5/6 (UX)

¿Cerrar la pestaña, o llevarla a una página local "Bloqueado: vuelve a lo tuyo"? Cerrar es lo más simple y no deja nada atrás. Una página propia explica qué pasó. La v1 cierra.
