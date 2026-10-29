# Fase 3: cerrar las pestañas de sitios bloqueados

> Especificación (borrador del 2026-10-28; actualizada el 2026-10-29 con el script ya escrito). Requiere la Fase 1. Contexto: [01-metodos-de-bloqueo.md](../investigacion/01-metodos-de-bloqueo.md#cuándo-hace-efecto-el-bloqueo-confianza-mediaalta).
>
> **Estado:** el script y sus pruebas están escritos (3.2 y la mitad de 3.3). Falta que el usuario haga la prueba de permisos (3.1). Su resultado decide quién ejecuta el script cada 15 s: un LaunchAgent, un atajo o la app de la Fase 5. Los cambios respecto al borrador están marcados con "(cambio)".

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
  - Los lee `hosts_parse` de `lib/hosts-block.zsh`, el mismo módulo del motor. **(cambio)** Ahora también deja la lista en `HOSTS_DOMAINS`.
  - Las líneas manuales fuera del bloque no cuentan.
- Así se respetan solos los pases de la Fase 4: los grupos con pase no están en el bloque, así que sus pestañas no se cierran.
- La comparación es por **nombre exacto** del host, igual que hace hosts. Por ejemplo `studio.youtube.com` no está en la lista, así que no se cierra.

### Script `close-tabs`

- **Ruta instalada:** la carpeta `/usr/local/libexec/efficiency-guardian/close-tabs/` (`root:wheel`, carpeta `755` y archivos `644`; el `.zsh`, `755`). Corre como el **usuario**, sin sudo, y **se niega a correr como root**.
- **Archivos** en `close-tabs/` del repositorio (regla D13; el más largo tiene 86 líneas):
  - `close-tabs.zsh`: lee el bloque de hosts y llama a cada navegador abierto. Carga `../lib/hosts-block.zsh`, que instalado es el módulo del motor.
  - `match.js`: extrae el host de una URL y decide si cerrar. No usa nada del navegador, así que se prueba solo.
  - `browser.js` **(cambio)**: recorre las ventanas y pestañas de **un** navegador y cierra las que coinciden. Sustituye a `chromium.js` y `safari.js` del borrador, porque los cinco navegadores usan los mismos nombres de AppleScript (`windows`, `tabs`, `url`, `close`). Si la prueba 3.1 muestra que Safari se comporta distinto, se separa.
  - `run.js` **(cambio)**: el punto de entrada (`run(argv)`) que llama osascript. Va aparte para que las pruebas puedan cargar `browser.js` con un `run` propio.
- **Pasos:**
  1. Leer el bloque de hosts y obtener la lista de dominios. Si está vacía, salir. Si los marcadores están dañados, salir con error sin cerrar nada.
  2. Por cada navegador **que ya esté abierto**, ejecutar `osascript -l JavaScript -e "$(<match.js)" -e "$(<browser.js)" -e "$(<run.js)" <bundle id> <dominio>...`. JXA no tiene `import`, así que los tres archivos se pasan juntos.
     - JXA (JavaScript for Automation) en vez de AppleScript, porque el usuario conoce JavaScript.
     - **Para saber si está abierto (cambio):** `lsappinfo find bundleid=…` en el zsh (escribe una línea si la app está abierta y nada si no; tarda unos 6 ms). Así no se lanza osascript para los navegadores cerrados. `run.js` lo repite con `Application(…).running()` justo antes, por si el navegador se cerró entretanto. **Nunca** se le habla a una app cerrada, porque eso la abriría.
  3. Escribir, y dejar en el registro del sistema, cuántas pestañas cerró cada navegador (solo si fueron más de 0) y los errores. Con el error `-1743` añade dónde dar el permiso. Sale con 1 si algo falló.
- **Cómo cierra `browser.js`** (para no tocar otras pestañas):
  - Busca cada ventana **por id**, no por posición: la posición cambia cada vez que el usuario usa otra ventana.
  - Lee todas las URL de la ventana en un solo evento.
  - Cierra de la última pestaña a la primera, para que cerrar una no mueva las anteriores.
  - **Vuelve a leer la URL justo antes de cerrar.** Si el usuario movió pestañas entretanto, en esa posición puede haber otra, y esa no se toca; la de YouTube se cierra en la siguiente vuelta.
  - Una ventana sin pestañas (Ajustes) o que desapareció se salta sin error.
- **Qué se cierra** (`match.js`): solo URL `http` o `https` cuyo host, en minúsculas, sin `usuario@`, sin puerto y sin punto final, esté en la lista. No se cierran `view-source:`, `chrome://`, `about:`, `file:` ni los dominios parecidos (`www.youtube.com.otro.com`, `otro.com/?volver=https://www.youtube.com`).
- **Navegadores** (identificadores verificados el 2026-10-28; los 4 Chromium traen diccionario AppleScript, `scripting.sdef`):

| Navegador | Bundle ID | Notas |
|---|---|---|
| Safari | `com.apple.Safari` | `windows`, `tabs`, `url` y `close` (verificar en 3.1) |
| Chrome | `com.google.Chrome` | Igual |
| Brave | `com.brave.Browser` | Igual que Chrome |
| Vivaldi | `com.vivaldi.Vivaldi` | Igual que Chrome (verificar) |
| Thorium | `org.chromium.Thorium` | Igual que Chrome (verificar) |

- **No hace falta** activar "Permitir JavaScript desde Apple Events" en los navegadores. Eso solo se necesita para ejecutar JS **dentro** de las páginas; aquí solo se leen URLs y se cierran pestañas.
- **Registro:**

```
/usr/bin/log show --last 1h --style compact \
  --predicate 'process == "logger" AND eventMessage BEGINSWITH "efficiency-guardian: close-tabs"'
```

### Disparador: LaunchAgent de usuario (pendiente de 3.1)

- **Propuesta:** `/Library/LaunchAgents/com.efficiency-guardian.close-tabs.plist`, de root, en vez de `~/Library/LaunchAgents/` como decía el borrador. Así lo instala y desinstala el instalador (root) igual que el resto, y quitarlo exige sudo, que es la misma fricción. Igual corre como el usuario (dominio `gui/<uid>`). **Decidirlo al escribir el instalador.**
- **Contenido:** `ProgramArguments = [/usr/local/libexec/efficiency-guardian/close-tabs/close-tabs.zsh]`, `StartInterval = 15`, `RunAtLoad = true`.
- **Coste:** cuando no hay bloqueo, el script sale de inmediato tras leer hosts. Con bloqueo, un osascript (unos 40 ms) por navegador abierto cada 15 s.
- **Cuando exista la app (Fase 5):** puede reemplazar este agente. La app ya está siempre abierta, puede cerrar pestañas **en el instante** en que cambia el estado y tendría su propio permiso de Automatización. Si la app ejecuta `close-tabs.zsh` como proceso hijo, macOS debería atribuir el permiso a la app, así que estos mismos archivos servirían (confianza media‑alta: es lo mismo que hace la terminal en la prueba A; confirmarlo en la Fase 5). Decidirlo en la Fase 5 (5.5).

## Riesgos a verificar primero (3.1: prueba de permisos, la hace el usuario)

1. **Permisos de Automatización (TCC):** la primera vez, macOS pide permiso para "controlar Brave" y los demás.
   - Con procesos en segundo plano (LaunchAgent → `osascript`), el aviso **puede no aparecer** y el script falla en silencio (error `-1743`).
   - Probar si aparece y a quién se atribuye: osascript, zsh, el script o Terminal.
   - **Consecuencia de seguridad a anotar:** si el permiso queda a nombre de `osascript` o `zsh` en general, cualquier otro script en segundo plano lanzado igual también podría controlar ese navegador. Podría leer las URL y abrir o cerrar pestañas, pero no ejecutar JavaScript dentro de las páginas mientras ese ajuste siga desactivado. Es un argumento a favor de que la app (Fase 5) absorba esta fase.
   - **Alternativa** si falla: ejecutar `close-tabs` desde el atajo justo después de `start` (el permiso queda a nombre de Atajos), o esperar a la app de la Fase 5.
2. **Ventanas privadas o de incógnito:** ¿JXA ve sus pestañas?
3. **Conexiones reutilizadas:** tras cerrar la pestaña, ¿una pestaña nueva de youtube.com carga durante unos segundos gracias a una conexión que sigue abierta? Si pasa, documentarlo. La opción manual es `chrome://net-internals/#sockets` → "Flush socket pools". **Esto no se puede probar en 3.1** (necesita el bloqueo real): va a 3.4.

### Cómo hacer la prueba: `tools/try-close-tabs.zsh` (sin sudo)

- **No toca `/etc/hosts`:** usa un hosts temporal que "bloquea" solo `example.com` y `www.example.com`.
- Copia `close-tabs/` y `lib/hosts-block.zsh` a una carpeta temporal. Así, en segundo plano, no depende de leer `~/Documents`, que macOS protege, y eso no confunde la prueba.
- **Antes**, en cada navegador que uses, abre:
  - `https://example.com` en una pestaña normal **y** en una ventana privada (se deben cerrar).
  - `https://example.org` (se debe quedar abierta).
- **A, desde la terminal:** `zsh tools/try-close-tabs.zsh terminal`. El permiso se pide a nombre de la terminal (Terminal o Visual Studio Code). Sirve de control: comprueba que el JavaScript funciona en cada navegador.
- **B, en segundo plano:** `zsh tools/try-close-tabs.zsh agent`. Carga un LaunchAgent temporal que ejecuta close-tabs una vez, espera hasta 3 minutos a que termine (para dar tiempo a responder los avisos), muestra lo que escribió y lo descarga. El plist queda en la carpeta temporal, no en `~/Library/LaunchAgents`, así que no se queda registrado.
- Vuelve a abrir las pestañas de `example.com` entre A y B.
- **Anotar** para cada navegador: si apareció el aviso, **a nombre de quién**, si se cerraron las pestañas normal y privada, y si `example.org` siguió abierta. Si B falla con `-1743` sin aviso, el LaunchAgent no sirve y se usa la alternativa.
- Los permisos dados se pueden quitar en Ajustes del Sistema → Privacidad y seguridad → Automatización.
- (El modo B se ensayó el 2026-10-29 con un close-tabs falso que no habla con navegadores: el LaunchAgent temporal se carga, corre, se lee su salida y se limpia.)

### Resultados de la prueba 3.1

_(Pendiente: los rellena el usuario o el agente con lo que el usuario cuente.)_

## Limitaciones conocidas

- **Diálogos "¿Salir del sitio?":** si una página pide confirmación antes de cerrarse (un borrador sin enviar en Facebook, por ejemplo), el cierre puede quedarse esperando la respuesta del usuario. Mientras tanto no corre otra vuelta. Vigilarlo en 3.4.
- **Un navegador que se cierra justo entre la comprobación y la llamada** podría volver a abrirse. La ventana es de milisegundos.
- **Las web apps** (sitios añadidos al Dock desde Safari, o PWA de Chrome) no son ventanas del navegador: sus pestañas no se cierran. El bloqueo de hosts sigue impidiendo cargas nuevas.
- **Un error que se repite** (por ejemplo, un permiso denegado) queda en el registro cada 15 s.

## Pruebas

- **Automáticas** (sin navegadores ni permisos; en `zsh tests/run.zsh`):
  - `tests/test-close-tabs-js.zsh`: ejecuta `match.js`, `browser.js` y `run.js` con el JavaScript real de osascript.
    - `match.js`: 18 URL, incluidos los 6 casos del borrador, mayúsculas, puerto, `usuario@`, punto final, dominios parecidos y `\`.
    - `browser.js`: recorre un navegador de mentira (`tests/fake-browser.js`). Comprueba que cierra solo las pestañas bloqueadas, que no falla si una ventana desaparece o no tiene pestañas, y que no cierra la pestaña equivocada si se movieron entretanto.
  - `tests/test-close-tabs.zsh`: `close-tabs.zsh` con osascript y lsappinfo de mentira (`tests/fake-commands.zsh`). Comprueba:
    - Sin bloqueo o sin navegadores abiertos, no llama a nadie.
    - Pasa los tres scripts y los dominios del bloque, en orden.
    - Con `-1743`, explica dónde dar el permiso y sigue con el siguiente navegador.
    - Con los marcadores dañados o sin hosts, sale con error sin llamar a nadie.
  - Para saber si las pruebas detectan errores, se rompió el código a propósito de 14 formas en una copia: todas fallaron.
  - `test-syntax.zsh` compila los `.js` con `osacompile` (sin ejecutarlos), y `check-length.zsh` revisa también `close-tabs/` y `tools/`.
- **Manuales** (el usuario), en cada navegador (3.4, tras instalar):
  - [ ] Un video de YouTube reproduciéndose + `start` → la pestaña se cierra en ≤15 s.
  - [ ] Las pestañas de LinkedIn y YouTube Studio siguen abiertas.
  - [ ] Con el navegador cerrado, no se abre solo.
  - [ ] (Con la Fase 4) Con un pase en curso, YouTube no se cierra; al vencer, sí (hasta 30 s del LaunchDaemon + 15 s de este agente).
  - [ ] Tras cerrarse la pestaña, ¿una pestaña nueva de YouTube carga por una conexión reutilizada? (riesgo 3)

## Opción a decidir en la Fase 5/6 (UX)

¿Cerrar la pestaña, o llevarla a una página local "Bloqueado: vuelve a lo tuyo"? Cerrar es lo más simple y no deja nada atrás. Una página propia explica qué pasó. La v1 cierra.
