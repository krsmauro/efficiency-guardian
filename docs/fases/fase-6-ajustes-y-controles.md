# Fase 6 (primera parte): ajustes y controles desde la app, sin Terminal

> **Especificación del 2026-10-29**, a partir de lo que pidió el usuario al ver la app (verificación 5.6). **Revisada por el usuario el mismo día** (a partir de un resumen): aceptó el cambio en la regla de acortar y los supuestos. Sin código todavía. Requiere las Fases 4 y 5. Lo demás que la Fase 6 tenía como candidato (Centro de control, estadísticas, página de "bloqueado") queda para después.

## Lo que pidió el usuario

1. **Nada de Terminal.** El submenú "Configuración" muestra `sudo nano …` en gris. "La idea de una interfaz es que el usuario no tenga que usar la Terminal."
2. **En una sesión por tiempo:** poder **alargarla** y **acortarla**. Regla del usuario para acortar: "añade los 5 minutos solo si el tiempo elegido ya se cumplió; si no, solo la acorta al tiempo elegido". **(cambio, aceptado por el usuario)** Acortar nunca termina antes que el retraso al terminar (ver A). No pidió pasar de una por tiempo a una sin fin.
3. **Pases para otros sitios, con fricción:** "para mí basta con YouTube, pero como app general, el usuario debería elegir qué sitios".

**Decisiones del usuario (2026-10-29):**
- **Para quién:** "yo ahora, otros después". Se construye para su Mac, sin cerrar la puerta a compartirla (ver al final).
- **Fricción de los ajustes:** **la contraseña del Mac al guardar** (la ventana de macOS). Es la misma barrera que hoy da `sudo`, sin Terminal.

## A. Alargar y acortar una sesión por tiempo

**Motor:**
- **Estado nuevo, `TIMED_STARTED`:** cuándo empezó la parte por tiempo. Hace falta porque una sesión sin fin convertida (S2) conserva su `SESSION_STARTED`: en la prueba del usuario, la sin fin empezó a las 12:48 y la de 25 min a las 13:55. "Acortar a 25 min" se mide desde las 13:55. Un estado sin esta clave (el de hoy) usa `SESSION_STARTED`.
- **`extend <min>`** (`<min>` de `TIMED_PRESETS`), solo con una sesión por tiempo: el fin se mueve `<min>` más tarde. Sin fricción: es más enfoque.
- **`shorten <min>`** (una duración de `TIMED_PRESETS` menor que la actual, `SESSION_ENDS − TIMED_STARTED`). Con `TIMED_LOCK=yes` se rechaza, como `stop`.
  - Si `TIMED_STARTED + <min>` llega después que `ahora + STOP_DELAY_MINUTES`: el fin pasa a esa hora.
  - Si no (ya pasó, o llegaría antes que el retraso): igual que `stop`, una terminación pendiente con el retraso, que "Seguir trabajando" puede anular.
  - **(cambio)** La regla del usuario terminaba sin retraso si la hora aún no había llegado. Así, en el minuto 22 de una sesión de 50, "acortar a 25" terminaba en 3 min, antes que "Terminar" (5 min): un atajo para saltarse el retraso. Ahora acortar nunca termina antes que el retraso, como ya pasa con la conversión S2. Lo aceptó el usuario el 2026-10-29.
- **Durante una terminación pendiente** no se ofrece ni alargar ni acortar: primero "Seguir trabajando".
- **Regla de sudoers:** `extend <d>` y `shorten <d>` por cada duración: 6 entradas más con la configuración actual.

**App:** con una sesión por tiempo, el menú muestra:
- "Alargar ▸ +25 min (hasta las 14:45)", y así con cada duración.
- "Acortar ▸ a 25 min (termina a las 14:20)", o "a 25 min (termina en 5 min: el retraso al terminar)" si llega antes que el retraso. Solo aparecen las duraciones menores que la actual. Con candado, el ítem sale desactivado y dice hasta cuándo.

## B. Pases para otros sitios

- **`PASS_GROUPS` ya existe.** Hoy, cada pase desbloquea todos esos grupos a la vez. Pasa a ser **la lista de sitios que un pase puede desbloquear**, uno por pase. Se elige en los ajustes (C), con la contraseña: esa es la fricción al configurar.
- **Motor:** `pass <grupo>` desbloquea solo ese grupo. Sin argumento desbloquea el primero de la lista (hoy, YouTube), para que lo de hoy siga funcionando.
  - Un pase a la vez.
  - Todos cuentan para `PASS_MAX_PER_SESSION`: el límite es compartido, para que más sitios no den más pases.
  - Estado nuevo `PASS_GROUP`. `status --json` añade `pass_group` y `groups` (todos los grupos de `blocklists/`, para la ventana de ajustes). Hay que regenerar los archivos de prueba del contrato.
- **Fricción al usarlo:** la de hoy, es decir, duración, número de pases y el registro. Más fricción (esperar 30 s antes de que empiece, escribir el motivo) queda sin decidir.
- **Regla de sudoers:** `pass <g>` por cada grupo de `PASS_GROUPS`. Por eso la regla depende también de `PASS_GROUPS`, y se regenera al guardar los ajustes.
- **App:** con un solo grupo, como hoy ("Pase YouTube, 5 min (quedan 3)"). Con varios, "Pase ▸ YouTube / Reddit / …".

## C. Ajustes en la app, con la contraseña al guardar

- **Una ventana "Ajustes…"** desde el menú. Sustituye el submenú "Configuración" de solo lectura. Muestra las duraciones, el candado, el retraso, la sesión al encender y los pases (minutos, cuántos y qué sitios).
- **Guardar:** la app valida los valores y ejecuta `guardian configure CLAVE=valor …` como root, con la ventana de contraseña de macOS. Usa AppleScript `do shell script … with administrator privileges`, desde la app con `NSAppleScript`.
  - [02](../investigacion/02-integracion-macos.md) lo descartó para un clic porque pide contraseña; aquí es justo lo que se quiere.
  - macOS recuerda la contraseña 5 min.
  - Cada argumento va con `quoted form of`.
- **Motor: `configure`** (nuevo). Solo root y **fuera de la regla de sudoers**, así que siempre pide la contraseña.
  1. **Valida** con la misma lógica de `config.zsh`. Nunca confía en la app.
  2. **Escribe la configuración** (temporal + `mv`, `root:wheel 644`), con los comentarios de `config.default`.
  3. **Regenera la regla de sudoers**, con la doble validación de `visudo`. El código está hoy en `install/sudoers.zsh` y pasa a `lib/` para que lo tenga el motor instalado.
  4. **Ejecuta `reconcile`**, para aplicar los cambios.
  - Así, cambiar las duraciones **ya no exige volver a ejecutar el instalador**.
- **Seguridad:**
  - La contraseña es el permiso.
  - `configure` solo escribe dos archivos fijos.
  - Los valores solo admiten letras, números, comas y guiones (como hoy).
- **Sin verificar:** que la ventana de contraseña salga desde una app con firma local en este macOS, y con qué nombre. Hay que hacer una prueba corta antes de escribir C. La hace el usuario, porque escribe su contraseña.

## "Yo ahora, otros después": qué se cuida ya

- **Un solo punto de entrada root (`guardian`), con argumentos exactos.** Para otros cambiará el transporte, no el motor: será un helper con `SMAppService.daemon`, que exige firma Developer ID (la firma local lo rompe, [02](../investigacion/02-integracion-macos.md)).
- **Nada atado a este Mac:** ni rutas ni nombres de usuario en el código. Comprobarlo en la app.
- **Los textos están en `GuardianCore`:** traducirlos después es posible.
- **Fuera hasta entonces:**
  - firma Developer ID y notarización (cuenta de Apple de pago, 99 USD al año);
  - instalador sin Terminal;
  - quitar la regla de sudoers.

## Orden propuesto

1. **A y B:** motor, regla de sudoers y app, con pruebas. Una sola reinstalación (`sudo ./install.sh`, la hace el usuario) y la verificación del usuario.
2. **La prueba de la ventana de contraseña.**
3. **C:** ajustes y `configure`.

## Preguntas resueltas por el usuario (2026-10-29)

1. **¿Acortar puede terminar antes que "Terminar"?** No: nunca antes que el retraso al terminar (ver A).
2. **¿Tope al alargar?** No. El texto del menú dice la hora nueva de fin.
3. **¿Límite de pases compartido entre sitios?** Sí.
