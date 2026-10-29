# Fase 6 (primera parte): ajustes y controles desde la app, sin Terminal

> **Especificación del 2026-10-29**, a partir de lo que pidió el usuario al ver la app (verificación 5.6). **Revisada por el usuario el mismo día** (a partir de un resumen): aceptó el cambio en la regla de acortar y los supuestos. Requiere las Fases 4 y 5. Lo demás que la Fase 6 tenía como candidato (Centro de control, estadísticas, página de "bloqueado") queda para después.
>
> **Estado (2026-10-29, sesión 8): A y B instalados y probados en parte; después, cambios pedidos por el usuario. El primer intento de instalarlos falló (la regla de sudoers); la regla corregida está sin instalar.** El usuario reinstaló el motor y la app, y "Alargar" funcionó sin contraseña. Al probarlo pidió poder pasar de 25 a 90 min y pasar a sin fin: ver [Cambios tras la primera prueba de A](#cambios-tras-la-primera-prueba-de-a-2026-10-29). Falta otra reinstalación y la [verificación](#verificación-manual-de-a-y-b-la-hace-el-usuario). C sigue sin código.

## Lo que pidió el usuario

1. **Nada de Terminal.** El submenú "Configuración" muestra `sudo nano …` en gris. "La idea de una interfaz es que el usuario no tenga que usar la Terminal."
2. **En una sesión por tiempo:** poder **alargarla** y **acortarla**. Regla del usuario para acortar: "añade los 5 minutos solo si el tiempo elegido ya se cumplió; si no, solo la acorta al tiempo elegido". **(cambio, aceptado por el usuario)** Acortar nunca termina antes que el retraso al terminar (ver A). No pidió pasar de una por tiempo a una sin fin. **(después)** Lo pidió al probar A: "Alargar ▸ Sin fin" (ver [Cambios tras la primera prueba de A](#cambios-tras-la-primera-prueba-de-a-2026-10-29)).
3. **Pases para otros sitios, con fricción:** "para mí basta con YouTube, pero como app general, el usuario debería elegir qué sitios".

**Decisiones del usuario (2026-10-29):**
- **Para quién:** "yo ahora, otros después". Se construye para su Mac, sin cerrar la puerta a compartirla (ver al final).
- **Fricción de los ajustes:** **la contraseña del Mac al guardar** (la ventana de macOS). Es la misma barrera que hoy da `sudo`, sin Terminal.

## A. Alargar y acortar una sesión por tiempo

**Motor:**
- **Estado nuevo, `TIMED_STARTED`:** cuándo empezó la parte por tiempo. Hace falta porque una sesión sin fin convertida (S2) conserva su `SESSION_STARTED`: en la prueba del usuario, la sin fin empezó a las 12:48 y la de 25 min a las 13:55. "Acortar a 25 min" se mide desde las 13:55. Un estado sin esta clave (el de hoy) usa `SESSION_STARTED`.
- **`extend <min>`** (`<min>` de `TIMED_PRESETS`), solo con una sesión por tiempo: el fin se mueve `<min>` más tarde. Sin fricción: es más enfoque. **(cambiado tras la primera prueba)** La sesión pasa a durar `<min>` en total, como `shorten`; y `extend` sin minutos la pasa a sin fin.
- **`shorten <min>`** (una duración de `TIMED_PRESETS` menor que la actual, `SESSION_ENDS − TIMED_STARTED`). Con `TIMED_LOCK=yes` se rechaza, como `stop`.
  - Si `TIMED_STARTED + <min>` llega después que `ahora + STOP_DELAY_MINUTES`: el fin pasa a esa hora.
  - Si no (ya pasó, o llegaría antes que el retraso): igual que `stop`, una terminación pendiente con el retraso, que "Seguir trabajando" puede anular.
  - **(cambio)** La regla del usuario terminaba sin retraso si la hora aún no había llegado. Así, en el minuto 22 de una sesión de 50, "acortar a 25" terminaba en 3 min, antes que "Terminar" (5 min): un atajo para saltarse el retraso. Ahora acortar nunca termina antes que el retraso, como ya pasa con la conversión S2. Lo aceptó el usuario el 2026-10-29.
- **Durante una terminación pendiente** no se ofrece ni alargar ni acortar: primero "Seguir trabajando".
- **Regla de sudoers:** `extend <d>` y `shorten <d>` por cada duración: 6 entradas más con la configuración actual. **(cambiado tras la primera prueba)** Ahora con patrones, sin depender de la configuración.

**App:** con una sesión por tiempo, el menú muestra:
- "Alargar ▸ +25 min (hasta las 14:45)", y así con cada duración. **(cambiado tras la primera prueba)** "Alargar ▸ a 90 min (hasta las 14:45)", solo las duraciones mayores que la actual, y siempre "Sin fin".
- "Acortar ▸ a 25 min (termina a las 14:20)", o "a 25 min (termina en 5 min: el retraso al terminar)" si llega antes que el retraso. Solo aparecen las duraciones menores que la actual. Con candado, el ítem sale desactivado y dice hasta cuándo.

## B. Pases para otros sitios

- **`PASS_GROUPS` ya existe.** Hoy, cada pase desbloquea todos esos grupos a la vez. Pasa a ser **la lista de sitios que un pase puede desbloquear**, uno por pase. Se elige en los ajustes (C), con la contraseña: esa es la fricción al configurar.
- **Motor:** `pass <grupo>` desbloquea solo ese grupo. Sin argumento desbloquea el primero de la lista (hoy, YouTube), para que lo de hoy siga funcionando.
  - Un pase a la vez.
  - Todos cuentan para `PASS_MAX_PER_SESSION`: el límite es compartido, para que más sitios no den más pases.
  - Estado nuevo `PASS_GROUP`. `status --json` añade `pass_group` y `groups` (todos los grupos de `blocklists/`, para la ventana de ajustes). Hay que regenerar los archivos de prueba del contrato.
- **Fricción al usarlo:** la de hoy, es decir, duración, número de pases y el registro. Más fricción (esperar 30 s antes de que empiece, escribir el motivo) queda sin decidir.
- **Regla de sudoers:** `pass <g>` por cada grupo de `PASS_GROUPS`. Por eso la regla depende también de `PASS_GROUPS`, y se regenera al guardar los ajustes. **(cambiado tras la primera prueba)** Ya no: un patrón admite cualquier nombre de grupo, y el motor rechaza los que no están en `PASS_GROUPS`.
- **App:** con un solo grupo, como hoy ("Pase YouTube, 5 min (quedan 3)"). Con varios, "Pase ▸ YouTube / Reddit / …".

## Cambios al escribir A y B (2026-10-29)

**Motor:**
- **(cambio) `status --json` añade también `timed_started`** (además de `pass_group`). La especificación no lo decía, pero la app lo necesita para calcular a qué duraciones se puede acortar y a qué hora terminaría cada una.
- **(cambio) `groups` (todos los grupos de `blocklists/`) queda para C**, que es quien lo usa. C exige reinstalar el motor de todos modos (por `configure`), así que esperar no cuesta una reinstalación más, y evita leer la carpeta de listas en cada `status` sin necesidad.
- **El motor también rechaza `extend` y `shorten` durante una terminación pendiente** ("anúlala primero (cancel-stop)"). La especificación solo decía que la app no los ofrece; así una sola acción nunca hace dos cosas.
- **Acortar a una hora que cae justo al terminar el retraso** cuenta como "antes que el retraso": terminación pendiente, que "Seguir trabajando" puede anular. Mismo resultado en la hora; la diferencia es que se puede anular. Motor y app usan la misma frontera.
- **Sin retraso (`STOP_DELAY_MINUTES=0`) y la hora elegida ya pasó:** termina en el acto, como `stop`. La app dice "termina ahora".
- **`pass` sin argumento sigue en la regla de sudoers** (desbloquea el primer grupo de `PASS_GROUPS`), para que la app anterior y un atajo que use `pass` sigan funcionando.
- **Estados escritos por el motor anterior:** sin `TIMED_STARTED`, se usa `SESSION_STARTED` (como decía la especificación); sin `PASS_GROUP` y con un pase en curso, el primer grupo de `PASS_GROUPS` (antes un pase desbloqueaba todos; con la configuración del usuario, solo YouTube, así que no cambia nada). Lo hace `session_upgrade` al leer.
- **Arreglado de paso el fallo de la pista de `stop`** ([Fase 4](fase-4-sesiones-y-tiempo.md#fallos-encontrados-en-la-verificación-manual)): `shorten` reutiliza ese mensaje. Ahora dice `sudo /usr/local/sbin/guardian cancel-stop`, sin punto final para que se pueda copiar tal cual.
- Módulos nuevos: `session-ending.zsh` (pedir el fin con el retraso, el candado y lo que exigen alargar y acortar; lo comparten `stop`, `extend` y `shorten`), `cmd-extend.zsh` y `cmd-shorten.zsh`. `config_require_preset` (en `config-check.zsh`) lo usan `start`, `extend` y `shorten`.

**App:**
- **Pase con varios sitios:** el submenú se llama "Pase, 5 min (quedan 3) ▸" y cada opción es el nombre del sitio. Si no se puede usar, una opción desactivada con el motivo ("Pase: no quedan (3 de 3)"); con un pase en curso dice cuál ("Pase Reddit: en curso hasta las 10:06").
- **"Acortar" con candado** sale como una opción desactivada, sin flecha: "Acortar: con candado hasta las 10:30". Si no hay ninguna duración menor que la actual, no aparece.
- **Los textos de alargar y acortar dicen horas, no cuentas atrás,** para no volver a cerrar los submenús abiertos (el fallo de 5.6). Solo cambian una vez, cuando una opción de acortar pasa a caer dentro del retraso.
- Los avisos del pase nombran solo el sitio del pase ("Reddit vuelve a bloquearse en unos segundos").
- Archivos nuevos: `MenuAction.swift` (opción, submenú y "opción o submenú"), `PassMenu.swift` y `SessionLengthMenu.swift`. `MenuModel.swift` (97 líneas) se dividió así antes de crecer.

**Pruebas:** motor de 612 a 707 comprobaciones (`test-extend.zsh` y `test-shorten.zsh` son nuevas); app de 63 a 73 pruebas (`PassMenuTests` y `SessionLengthMenuTests` nuevas, y una de punta a punta con el motor del repositorio). Los archivos del contrato se regeneraron. **Se rompió el código a propósito de 28 formas en una copia (17 en el motor, 11 en la app): todas fallaron.**

**Comprobado sin sudo en este Mac:** el motor nuevo lee bien el estado instalado (formato anterior), y la regla de sudoers que generará el instalador con la configuración instalada pasa `visudo`.

**Ojo:** la configuración instalada tiene `PASS_GROUPS=youtube`. Hasta que haya más de un sitio en esa lista, el pase se ve igual que antes. Añadir sitios hoy exige `sudo nano` (C quita eso); desde los cambios de abajo, ya no exige reinstalar.

## Cambios tras la primera prueba de A (2026-10-29)

El usuario reinstaló el motor (14:37) y la app. Primero vio la app anterior: no la había cerrado antes de copiar la nueva, y `open` mostró la que seguía abierta. Con la nueva, **"Alargar" funcionó sin contraseña**: el registro muestra `extend 25` y `extend 90` a las 18:13, y después un `stop` desde la app. Al usarlo pidió dos cosas, y aceptó la propuesta del agente:

- **"No puedo pasar de una sesión de 25 min a una de 90."** "Alargar" sumaba minutos (+25, +50, +90 daban 50, 75 o 115 en total). **Ahora elige la duración total**, como "Acortar": `extend <min>` hace que la sesión dure `<min>` desde `TIMED_STARTED`. Solo se aceptan duraciones mayores que la actual ("la sesión dura 50 min: solo se puede alargar a más"), y el menú solo ofrece esas.
- **"No hay opción para sesiones sin fin."** Era a propósito (D16), pero lo pidió. **`extend` sin minutos pasa la sesión a sin fin** ("Alargar ▸ Sin fin", siempre presente). Así alargar sigue sin tope, como pidió en D16.
  - Conserva `SESSION_STARTED`, los pases usados y el pase en curso, como la conversión S2 al revés. Como toda sesión sin fin, termina con `stop` o al apagar el Mac.
  - **Con candado se rechaza**, y en el menú sale desactivado ("Sin fin: con candado hasta las 10:30"). Una sesión sin fin se termina con `stop`, y el candado no aplica a las sesiones sin fin: sería saltárselo.
  - Durante una terminación pendiente se rechaza, como alargar.
  - **Por qué un comando nuevo y no `start`:** `start` es lo que mandará la Concentración (Fase 3). Si pasara a sin fin, activar la Concentración durante una sesión de 50 min la volvería sin fin.
- **La regla de sudoers ya no depende de la configuración** (lo aceptó el usuario). Con patrones: `start`, `extend` y `shorten` admiten un número de 1 a 3 cifras, y `pass` un nombre de grupo. Después el motor rechaza lo que no está en la configuración. Cambiar `TIMED_PRESETS` o `PASS_GROUPS` ya no exige reinstalar, y el paso 3 de C ("regenera la regla de sudoers") sobra. Detalle en la [Fase 4](fase-4-sesiones-y-tiempo.md#regla-de-sudoers).
  - **Primer intento fallido (2026-10-29):** se instaló con `G start ""` y `G start ^[1-9]…$`, y el Mac pidió contraseña para todo. sudo solo lee un patrón si los argumentos **empiezan** con `^` (el subcomando debe ir dentro: `G ^start [1-9]…$`), y `""` significa "ninguno" solo si va solo. El agente había leído mal el manual y escrito que la regla anterior admitía cualquier argumento: **era falso**, la regla anterior era exacta. Corregido en [02](../investigacion/02-integracion-macos.md#reglas-para-la-regla-de-sudoers-confianza-alta-man-sudoers-local) y verificado en el código de sudo.
  - **`visudo` no basta:** solo comprueba la sintaxis. `tests/test-sudoers.zsh` imita la comparación de sudo y falla con el primer intento. Lo que confirma la regla es que la app funcione sin contraseña.

**Pruebas:** motor de 707 a 778 comprobaciones (`test-sudoers.zsh` es nueva); app de 73 a 75 pruebas. Se rompió el código a propósito de 18 formas en una copia (7 en el motor, 5 en la regla, incluido el primer intento, y 6 en la app): todas fallaron.

## Verificación manual de A y B (la hace el usuario)

Antes, una sola vez y en este orden, seguidos: `sudo ./install.sh` (la regla nueva y los módulos), y después cambiar la app: **cerrarla primero** (Salir), `rm -rf /Applications/EfficiencyGuardian.app`, `cp -R app/build/EfficiencyGuardian.app /Applications/` y `open /Applications/EfficiencyGuardian.app`. **Primero el motor:** con el motor anterior, "Sin fin" pide contraseña y "a 90 min" sumaría 90. Entre los dos pasos, la app anterior con el motor nuevo ofrece "+25" con otro significado: no usarla.

Lo más importante primero (cada uno prueba una parte de la regla nueva):
- [ ] **Primero, sin cambiar nada:** en Terminal, `sudo -K; sudo -n /usr/local/sbin/guardian start 999` debe decir "999 min no es una duración permitida" (sudo lo dejó pasar y el motor lo rechazó). Si dice "a password is required", la regla sigue mal. `sudo -K` olvida la contraseña recién escrita; sin él, la prueba pasaría por la contraseña y no por la regla.
- [x] ~~Con una sesión de 25 min: "Alargar ▸ +25 min" funciona sin contraseña~~ (la versión que sumaba, 2026-10-29).
- [ ] Nueva sesión de 25 min, sin contraseña (`start <min>`). "Alargar ▸ a 90 min": sin contraseña, y el resumen dice que termina 90 min después del inicio (`extend <min>`).
- [ ] "Acortar ▸ a 50 min": sin contraseña (`shorten <min>`).
- [ ] "Alargar ▸ Sin fin": sin contraseña, el resumen dice "Sesión sin fin" y los pases usados no cambian (`extend` a secas).
- [ ] El pase de YouTube (`pass <grupo>`), y "Terminar sesión" y "Seguir trabajando" (`stop` y `cancel-stop`).
- [ ] Con los submenús "Alargar" y "Acortar" abiertos unos segundos, no se cierran solos.
- [ ] (Opcional, con `sudo nano` y **sin** reinstalar) Con `PASS_GROUPS=youtube,reddit`: "Pase ▸ Reddit" desbloquea Reddit y no YouTube.

## C. Ajustes en la app, con la contraseña al guardar

- **Una ventana "Ajustes…"** desde el menú. Sustituye el submenú "Configuración" de solo lectura. Muestra las duraciones, el candado, el retraso, la sesión al encender y los pases (minutos, cuántos y qué sitios).
- **Guardar:** la app valida los valores y ejecuta `guardian configure CLAVE=valor …` como root, con la ventana de contraseña de macOS. Usa AppleScript `do shell script … with administrator privileges`, desde la app con `NSAppleScript`.
  - [02](../investigacion/02-integracion-macos.md) lo descartó para un clic porque pide contraseña; aquí es justo lo que se quiere.
  - macOS recuerda la contraseña 5 min.
  - Cada argumento va con `quoted form of`.
- **Motor: `configure`** (nuevo). Solo root y **fuera de la regla de sudoers**, así que siempre pide la contraseña.
  1. **Valida** con la misma lógica de `config.zsh`. Nunca confía en la app.
  2. **Escribe la configuración** (temporal + `mv`, `root:wheel 644`), con los comentarios de `config.default`.
  3. ~~**Regenera la regla de sudoers**~~. **Ya no hace falta** (2026-10-29): la regla no depende de la configuración.
  4. **Ejecuta `reconcile`**, para aplicar los cambios.
  - Cambiar las duraciones ya no exige volver a ejecutar el instalador (desde los cambios tras la primera prueba de A, sin esperar a C).
- **Seguridad:**
  - La contraseña es el permiso.
  - `configure` solo escribe dos archivos fijos.
  - Los valores solo admiten letras, números, comas y guiones (como hoy).
- **Sin verificar:** que la ventana de contraseña salga desde una app con firma local en este macOS, y con qué nombre. Hay que hacer una prueba corta antes de escribir C. La hace el usuario, porque escribe su contraseña.

## "Yo ahora, otros después": qué se cuida ya

- **Un solo punto de entrada root (`guardian`), con argumentos acotados** (patrones en la regla de sudoers; el motor valida el resto). Para otros cambiará el transporte, no el motor: será un helper con `SMAppService.daemon`, que exige firma Developer ID (la firma local lo rompe, [02](../investigacion/02-integracion-macos.md)).
- **Nada atado a este Mac:** ni rutas ni nombres de usuario en el código. Comprobarlo en la app.
- **Los textos están en `GuardianCore`:** traducirlos después es posible.
- **Fuera hasta entonces:**
  - firma Developer ID y notarización (cuenta de Apple de pago, 99 USD al año);
  - instalador sin Terminal;
  - quitar la regla de sudoers.

## Orden propuesto

1. **A y B:** motor, regla de sudoers y app, con pruebas. ✅ Escrito e instalado el 2026-10-29; alargar probado. Con los cambios tras la primera prueba, falta otra reinstalación y la verificación del usuario.
2. **La prueba de la ventana de contraseña.**
3. **C:** ajustes y `configure`.

## Preguntas resueltas por el usuario (2026-10-29)

1. **¿Acortar puede terminar antes que "Terminar"?** No: nunca antes que el retraso al terminar (ver A).
2. **¿Tope al alargar?** No. El texto del menú dice la hora nueva de fin. **(después)** Alargar elige la duración total, hasta la mayor de `TIMED_PRESETS`, y "Sin fin" quita el tope.
3. **¿Límite de pases compartido entre sitios?** Sí.
