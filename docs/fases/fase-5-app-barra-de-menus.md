# Fase 5: app de barra de menús en Swift (v1)

> **Especificación lista y código escrito el 2026-10-29 (pasos 5.1 a 5.4).** Una revisión independiente encontró 6 fallos, ya arreglados en el código pero **sin probar a mano** (ver "Fallos de la revisión"). El borrador era del 2026-10-28; los cambios están marcados con **(cambio)**. Requiere la Fase 4, que aporta `guardian status --json` y todos los comandos. **Nada de la app se ha probado con el motor instalado** (no lo está todavía): falta la verificación del usuario (5.6). Contexto técnico: [02-integracion-macos.md](../investigacion/02-integracion-macos.md#si-algún-día-hay-app-propia-en-swift-fase-opcional).

## Lo que pidió el usuario (D12)

- "Usemos Swift."
- "La UI requiere más investigación y pruebas. Si usamos Swift, tenemos que hacer que provea una **experiencia de usuario asombrosa**."
- "Por ahora la app de barra de menús es suficiente, pero tenemos que mejorarla en el futuro." Esa mejora es la Fase 6.

**Consecuencia:** la v1 debe ser **funcional, clara y estable**, no espectacular. Todo lo que sea pulido, animación, widget del Centro de control o ventana de configuración va a la Fase 6, después de investigar y probar.

## Alcance de la v1

### El ícono de la barra de menús siempre dice el estado

Si hay varias cosas a la vez, manda la primera de la tabla:

| Estado | Ícono (SF Symbol) | Texto |
|---|---|---|
| No se pudo leer el estado, o el motor no está instalado | `exclamationmark.triangle` | — |
| Pase en curso | `ticket` | `3:12` |
| Terminación pendiente | `hourglass` | `4:10` |
| Sesión por tiempo | `lock.fill` | `47m` (desde 1 h: `1h05`) |
| Sesión indefinida | `lock.fill` | — |
| Sin sesión | `lock.open` | — |

- **(cambio)** Sin sesión, el candado abierto no va "atenuado": la barra de menús no respeta la opacidad. Se distingue por la forma (abierto frente a cerrado).
- La cuenta atrás de la terminación pendiente usa la hora a la que termina **de verdad**: `stop_at`, o el fin de la sesión por tiempo si llega antes (igual que `guardian status`).

### Menú al hacer clic

1. **Resumen** (líneas sin acción): tipo de sesión y hora de fin, terminación pendiente, pase en curso, "Pases usados: 1 de 3" y cuántos dominios bloquea hosts ahora.
2. **Pase YouTube, 5 min (quedan 2):** desactivado y con el motivo si no hay sesión, si ya hay un pase en curso o si no quedan. Se oculta con `PASS_MAX_PER_SESSION=0`.
3. **Nueva sesión ▸** cada valor de `TIMED_PRESETS` y "Sin fin", solo sin sesión. **Con una sesión indefinida, el submenú se llama "Pasar a sesión por tiempo ▸"** y ofrece solo las duraciones (S2 de la Fase 4). Si una duración es menor que el retraso al terminar, el motor la alarga, y el texto lo dice: "3 min (serán 5: el retraso al terminar)". Con una sesión por tiempo no aparece.
4. **Terminar sesión (en 5 min):** si la sesión por tiempo acaba antes que el retraso, dice "Terminar sesión (ya termina a las 10:30)". Con candado aparece desactivado: "Terminar: con candado hasta las 10:30". Durante una terminación pendiente se sustituye por:
5. **Seguir trabajando**, que llama a `cancel-stop`.
6. **Configuración ▸** (solo lectura): los valores actuales y cómo cambiarlos (`sudo nano …` y volver a ejecutar el instalador si cambian las duraciones).
7. **Abrir al iniciar sesión** (casilla). **(cambio)** El borrador no la tenía: la app se registra sola la primera vez que se abre **desde /Applications**, y la casilla permite quitarlo.
8. **Salir.**

**Sin motor instalado o con un error al leer el estado,** el menú lo explica y ofrece "Reintentar" en vez de las acciones.

**Mientras un comando está en marcha** las acciones se desactivan, para que un doble clic no lance dos.

**(cambio) Si un comando falla,** una alerta muestra el mensaje del motor, después de volver a leer el estado (por ejemplo, "No quedan pases en esta sesión (3/3)"). Si sudo pide contraseña, explica que la regla de sudoers no permite ese comando: o el motor no está instalado, o cambió `TIMED_PRESETS` sin volver a ejecutar el instalador. El borrador no decía cómo mostrar los errores; una notificación podía estar desactivada, y una alerta no necesita permiso. La alerta se abre desde el run loop (`RunLoop.main.perform`) y no dentro de la tarea que ejecutó el comando: si no, mientras está abierta se congelan las lecturas del estado (fallo 1 de la revisión).

### Notificaciones

| Cuándo | Texto |
|---|---|
| Queda 1 minuto de pase (solo si el pase dura más de 1 min) | "Queda 1 minuto de pase" |
| El pase terminó y la sesión sigue | "Pase terminado: YouTube vuelve a bloquearse en unos segundos" |
| La terminación pendiente se cumplió | "Sesión terminada: se cumplió el retraso" |
| La sesión por tiempo llegó a su hora | "Sesión terminada: se acabó el tiempo" |
| La sesión sin fin arrancó al encender el Mac | "Modo enfoque activado al encender el Mac" |

- **(cambio) Solo se avisa de lo que acaba de pasar** (en los últimos 2 minutos). Si el Mac estuvo dormido cuando venció un pase, al despertar no llega un aviso viejo.
- **(cambio) Sin aviso** cuando la sesión termina por una acción del usuario sin retraso (`STOP_DELAY_MINUTES=0`) o por reiniciar: el usuario ya lo sabe.
- "Arrancó al encender": la sesión es sin fin, `AUTOSTART_AT_BOOT=yes`, empezó en los 10 minutos siguientes al arranque del Mac (`kern.boottime`) y hace menos de 10 minutos. Así no se repite si la app se vuelve a abrir más tarde. El arranque ya avisado se guarda (`UserDefaults`), así que tampoco se repite si la app se cierra y se abre poco después del arranque.
- **"Vuelve a bloquearse en unos segundos"** es honesto: la app se entera al instante (calcula la hora), pero quien reescribe hosts es `reconcile`, cada 30 s.

### Abrir al iniciar sesión

La app se registra como ítem de inicio la primera vez que se abre **desde `/Applications`** (`SMAppService.mainApp`); si falla, lo reintenta la próxima vez. Desde otra carpeta no se registra sola: `app/build` se borra en cada compilación y el ítem apuntaría a una app que ya no existe. La casilla del menú lo quita o lo vuelve a poner, y se vuelve a leer en cada lectura del estado (puede cambiar desde Ajustes).

## Decisiones técnicas

- **Framework:** SwiftUI `MenuBarExtra` con estilo `.menu` (un menú nativo). Objetivo: macOS 26+. `LSUIElement = YES`, para que no salga en el Dock.
- **Sin sandbox:** la app ejecuta `sudo` y el motor. No se va a publicar en la App Store.
- **Acciones:** `Process` con `/usr/bin/sudo -n /usr/local/sbin/guardian <comando>`, con argumentos **idénticos** a los de la regla de sudoers. Rutas fijas, entorno limpio (solo `PATH`), entrada estándar vacía: `sudo -n` nunca espera una contraseña.
  - No necesita helper privilegiado ni `SMAppService.daemon`, y por tanto ninguno de sus problemas de firma.
  - La app no da más poder que la regla de sudoers: cualquier programa del usuario ya podía ejecutar esos comandos.
- **Esperar a un programa bloquea un hilo, así que cada ejecución usa hilos propios (`Thread`)**, que no salen de ningún grupo con tope:
  - Primero usaba los de Swift concurrency (async/await): son tantos como núcleos (10 en este Mac). Con más programas a la vez, todos esperaban una salida que nadie leía y todo se colgaba. Lo encontraron las pruebas el 2026-10-29 (a veces pasaban y otras se colgaban).
  - Después, los de GCD: tienen un tope de 64, y con 64 programas a la vez pasaba lo mismo (fallo 2 de la revisión).
  - La app ejecuta como mucho 2 a la vez, así que en la práctica no pasaba; hay una prueba con 70 que lo reproduce.
- **Cuándo toca volver a leer se cuenta desde la hora del motor en la lectura** (`now` del JSON), no desde que la app recibió la respuesta (fallo 3 de la revisión). El sondeo de 30 s usa un reloj monótono: cambiar la hora del Mac no lo detiene.
- **Leer el estado:** `guardian status --json`, sin sudo. Las duraciones del menú salen de ahí (`timed_presets`), no de la app.
- **Cuándo se vuelve a leer** (cada lectura lanza el motor, unos milisegundos):
  - Al abrir la app, tras cada acción y al despertar el Mac.
  - **Al llegar cada hora de fin** (pase, retraso, sesión): `status` ya muestra la sesión como la dejará `reconcile`, así que el ícono cambia en el acto.
  - **Cuando cambia la carpeta de datos** (`/var/db/efficiency-guardian`), vigilada con `DispatchSource`. Se vigila la carpeta y no el archivo porque el motor escribe el estado con "temporal + `mv`", que cambia el archivo. Así se notan al instante los cambios de Atajos y de `reconcile`.
  - Y cada 30 s por si acaso.
- **El reloj de la cuenta atrás** se calcula en la app a partir de las horas de fin: un temporizador de 1 s (en el modo `.common` del run loop, para que siga con el menú abierto).
- **Abrir al iniciar sesión:** `SMAppService.mainApp.register()`. **Verificar** que funciona con la firma local (5.6). Si no, añadirla a mano en Ajustes → General → Ítems de inicio.
- **Firma:** local ("ad-hoc", `codesign --sign -`), hecha por el script de compilación. No hace falta cuenta de Apple: no hay extensión ni daemon dentro de la app.
- **(cambio) Proyecto: un paquete de Swift (`app/Package.swift`), no un proyecto de Xcode.**
  - Todos los archivos son texto legible; el `.pbxproj` de Xcode no se puede revisar a mano.
  - Se compila y se prueba desde la Terminal (`swift build`, `swift test`), así que el agente puede verificarlo sin hacer clic en Xcode.
  - Xcode lo abre igual (abrir `app/Package.swift`) para editar o depurar.
  - El precio: `app/build.zsh` arma el paquete `.app` (Info.plist, binario y firma). Son pocas líneas.
- **Regla de tamaño (D13):** un tipo o una vista por archivo, con unas 100 líneas como máximo. `tests/check-length.zsh` también revisa `app/`.
- **Fase 3 dentro de la app (5.5, sin decidir):** la app podría cerrar las pestañas ella misma en el instante en que cambia el estado, con su propio permiso de Automatización, y retirar el LaunchAgent. Se decide con el resultado de la prueba de permisos 3.1.

## Archivos

La lógica que decide qué se muestra no toca el sistema y se prueba sola; la parte que habla con macOS es delgada. El archivo más largo tiene 97 líneas.

**`GuardianCore`** (biblioteca, sin interfaz; con pruebas):

| Archivo | Responsabilidad |
|---|---|
| `GuardianStatus.swift` | El JSON de `status --json`, decodificado y validado; horas efectivas de fin |
| `StatusResult.swift` | Interpretar la salida de `status`: estado, motor no instalado o error |
| `GuardianCommand.swift` | Los comandos y sus argumentos exactos (los de la regla de sudoers) |
| `CommandOutcome.swift` | Interpretar la salida de un comando: mensaje del motor, o el error explicado |
| `EngineMessage.swift` | Quitar el prefijo `guardian: error:` a los mensajes del motor |
| `ProcessRunner.swift` | Ejecutar un programa y leer su salida. **(cambio)** Estaba en la app; se movió aquí para probarlo con programas de verdad. Es lo único de la biblioteca que toca el sistema. |
| `TimeText.swift` | `47m`, `1h05`, `3:12`, `10:30` |
| `GroupNames.swift` | `youtube` → "YouTube" |
| `IconState.swift` | Qué ícono y qué texto lleva la barra de menús |
| `MenuModel.swift` | Qué opciones tiene el menú, activas o no, con su texto |
| `MenuSummary.swift` | Las líneas de resumen y de configuración del menú |
| `NotificationPlanner.swift` | Qué notificaciones enviar al cambiar el estado o pasar el tiempo |

**`GuardianBar`** (la app; se prueba a mano):

| Archivo | Responsabilidad |
|---|---|
| `GuardianBarApp.swift` | Punto de entrada: la escena `MenuBarExtra` |
| `AppModel.swift` | El estado que ve la interfaz; leer el estado y ejecutar comandos |
| `Scheduler.swift` | Temporizador de 1 s, horas de fin, sondeo de 30 s y despertar del Mac |
| `GuardianClient.swift` | `status --json` y `sudo -n guardian …` |
| `StateWatcher.swift` | Vigilar la carpeta de datos |
| `MenuBarLabel.swift`, `MenuContent.swift`, `SettingsMenu.swift` | Las vistas |
| `Notifier.swift` | Enviar notificaciones |
| `LoginItem.swift` | Abrir al iniciar sesión |
| `Alerts.swift` | La alerta de error de un comando |
| `SystemClock.swift` | La hora actual y la del arranque del Mac (`kern.boottime`) |

**Otros:** `app/Info.plist` (datos), `app/build.zsh` (compila y arma `app/build/EfficiencyGuardian.app`; no instala nada).

## Pruebas

- **`swift test --package-path app`** prueba `GuardianCore` (Swift Testing, 59 pruebas, menos de 1 s). `app/build.zsh` las ejecuta antes de compilar y se niega a seguir si fallan. **No forman parte de `tests/run.zsh`**: el instalador ejecuta esas pruebas antes de instalar el motor, y no debe depender de compilar Swift.
- **Con el motor de verdad:** `EngineIntegrationTests.swift` ejecuta el `bin/guardian` del repositorio sin root sobre un hosts temporal (como `tests/e2e.zsh`) y comprueba que los comandos de la app, sus argumentos y su forma de leer las respuestas encajan con el motor. Lo único que no prueba es la ruta instalada con `sudo -n`.
- **¿Detectan errores?** Se rompió el código a propósito de 24 formas en una copia (18 al escribirlo y 6 volviendo a meter los fallos de la revisión): todas fallaron. Tres (en `ProcessRunner`) se detectan porque las pruebas **se cuelgan**, no porque fallen: es la naturaleza de ese fallo.
- **Sin pruebas automáticas:** la parte de la app que habla con macOS (`GuardianBar`: vistas, alertas, ítem de inicio, notificaciones, temporizador). Solo se comprobó que la app arranca y sigue viva 5 s sin el motor instalado (binario suelto, sin registrar nada en el Mac).

## Fallos de la revisión (2026-10-29): arreglados, sin probar a mano

Una revisión independiente (un agente aparte, buscando fallos) encontró uno de gravedad media y cinco leves. Se arreglaron antes de que el usuario pidiera **no escribir más código sin prueba manual**. Los arreglos de `GuardianCore` tienen pruebas; los de la app (1 y 4), no: **se comprueban en 5.6**. Si alguno falla, anotarlo en la bitácora de [PLAN.md](../../PLAN.md); no arreglarlo sin que el usuario lo pida.

| # | Gravedad | Fallo | Arreglo | ¿Probado? |
|---|---|---|---|---|
| 1 | Media | Con la alerta de error abierta, la app dejaba de leer el estado: la cuenta atrás bajaba sobre datos viejos y no veía los cambios de Atajos | La alerta se abre desde el run loop; el estado se lee antes de mostrarla (`Alerts.swift`, `AppModel.swift`) | **No** (necesita la interfaz) |
| 2 | Leve | `ProcessRunner` se colgaba con 64 programas a la vez (tope de GCD) | Hilos propios (`Thread`) | Sí (prueba con 70) |
| 3 | Leve | Si una lectura cruzaba una hora de fin, la app la veía 30 s tarde; el sondeo dependía de la hora del Mac | Contar desde la hora del motor; reloj monótono para el sondeo | Sí (la hora de fin); el reloj monótono, no |
| 4 | Leve | El ítem de inicio se registraba desde cualquier carpeta (también `app/build`, que se borra), sin reintentar si fallaba, y la casilla no se actualizaba | Solo desde `/Applications`, reintento, se vuelve a leer en cada lectura (`LoginItem.swift`) | **No** (necesita la app instalada) |
| 5 | Leve | El aviso "activado al encender" se repetía si la app se cerraba y se abría poco después del arranque | Se guarda el arranque avisado | Sí |
| 6 | Leve | Textos que no decían lo que hace el motor: pase que cubre todos los grupos, duración menor que el retraso, terminar cuando la sesión acaba antes | Textos nuevos (ver "Menú al hacer clic") | Sí |
- **Contrato entre el motor y la app:** `tests/test-app-contract.zsh` (sí está en `tests/run.zsh`) ejecuta el motor real y comprueba que su `status --json` coincide byte a byte con los archivos de `app/Tests/GuardianCoreTests/Fixtures/`. Las pruebas de Swift decodifican esos mismos archivos. Si alguien cambia `status-json.zsh`, falla `tests/run.zsh` hasta que se regeneren (`zsh tests/test-app-contract.zsh --write`) y la app se adapte.

## Compilar e instalar (lo hace el usuario, sin sudo)

```
zsh app/build.zsh                                   # compila y arma app/build/EfficiencyGuardian.app
cp -R app/build/EfficiencyGuardian.app /Applications/
open /Applications/EfficiencyGuardian.app
```

Va en `/Applications` para que el ítem de inicio apunte a un lugar fijo. Un administrador puede copiar ahí sin sudo. **Solo tiene sentido con el motor instalado** (1.5); sin él, la app dice que falta.

## Fuera de la v1 (→ Fase 6)

- Interruptor en el Centro de control (`ControlWidgetToggle`; firma gratuita sin confirmar).
- Ventana de configuración editable. Debería pedir la contraseña de administrador al guardar, para conservar la fricción.
- Atajo de teclado global, sonidos, animaciones, pantalla de bienvenida, ícono propio de la app.
- Estadísticas: tiempo enfocado, pases por día.
- Página propia de "bloqueado" en vez de cerrar pestañas.

## Verificación manual (5.6, la hace el usuario con el motor instalado)

- [ ] El ícono cambia en ≤2 s tras cada acción del menú, y al instante tras activar o desactivar la Concentración (Fase 2).
- [ ] Al vencer un pase o una sesión, el ícono cambia en el acto (sin esperar a `reconcile`), y hosts en ≤30 s.
- [ ] Cada opción del menú funciona sin pedir contraseña.
- [ ] Las opciones no disponibles aparecen desactivadas y con el motivo.
- [ ] Al abrirla por primera vez, macOS pide permiso para las notificaciones. **Con la firma local, ¿llegan?** (sin verificar)
- [ ] La app se abre sola al iniciar sesión. **¿Funciona `SMAppService.mainApp` con la firma local?** (sin verificar; si no, añadirla a mano en Ajustes → General → Ítems de inicio)
- [ ] Tras reiniciar el Mac con `AUTOSTART_AT_BOOT=yes`, el ícono muestra la sesión indefinida y llega el aviso "Modo enfoque activado al encender el Mac".
- [ ] Con el menú abierto, la cuenta atrás sigue avanzando.
- [ ] Error explicado: cambiar `TIMED_PRESETS` sin volver a ejecutar el instalador → elegir la duración nueva → la alerta dice que la regla de sudoers no la permite.
- [ ] **Fallo 1 de la revisión:** con esa alerta abierta, activar o desactivar la Concentración (o esperar a que venza un pase): el ícono cambia aunque la alerta siga abierta.
- [ ] La alerta aparece delante, no detrás de otras ventanas (`NSApp.activate()` en una app sin Dock; sin verificar).
- [ ] **Fallo 4 de la revisión:** abrir la app desde `app/build` no la registra al iniciar sesión; desde `/Applications`, sí. Quitar el ítem en Ajustes → General → Ítems de inicio y abrir el menú: la casilla aparece desmarcada.
- [ ] El ícono muestra el símbolo y el texto juntos, y las cifras no bailan al cambiar los segundos (sin verificar: cómo dibuja `MenuBarExtra` la etiqueta).
- [ ] Con el menú abierto, ¿se actualizan también sus líneas (resumen, pases)? Si no, anotarlo (no es grave).
- [ ] Tras un rato sin tocar el Mac, la cuenta atrás sigue al segundo (sin verificar: App Nap podría frenar el temporizador).
