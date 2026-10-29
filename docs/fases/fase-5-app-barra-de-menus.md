# Fase 5: app de barra de menús en Swift (v1)

> Borrador de especificación (2026-10-28). Requiere la Fase 4, que aporta `guardian status --json` y todos los comandos. Contexto técnico: [02-integracion-macos.md](../investigacion/02-integracion-macos.md#si-algún-día-hay-app-propia-en-swift-fase-opcional).

## Lo que pidió el usuario (D12)

- "Usemos Swift."
- "La UI requiere más investigación y pruebas. Si usamos Swift, tenemos que hacer que provea una **experiencia de usuario asombrosa**."
- "Por ahora la app de barra de menús es suficiente, pero tenemos que mejorarla en el futuro." Esa mejora es la Fase 6.

**Consecuencia:** la v1 debe ser **funcional, clara y estable**, no espectacular. Todo lo que sea pulido, animación, widget del Centro de control o ventana de configuración va a la Fase 6, después de investigar y probar.

## Alcance de la v1

### El ícono de la barra de menús siempre dice el estado

| Estado | Ejemplo de ícono |
|---|---|
| Sin sesión | candado abierto, atenuado |
| Sesión indefinida | candado cerrado |
| Sesión por tiempo | candado + tiempo restante: `47m` |
| Pase en curso | indicador de pase + `3:12` |
| Terminación pendiente | indicador de espera + `4:10` |

(Íconos concretos: SF Symbols, a decidir al implementar.)

### Menú al hacer clic

- **Estado:** tipo de sesión, hora de fin, "Pases: 2 de 3".
- **Pase YouTube (5 min):** desactivado si no quedan pases o no hay sesión.
- **Nueva sesión ▸** cada valor de `TIMED_PRESETS` y "Sin fin". Solo cuando no hay sesión, o para convertir una indefinida (S2 de la Fase 4).
- **Terminar sesión:** si hay retraso, el texto dice "Terminar (en 5 min)". Con candado aparece desactivado, con la hora de fin.
- **Seguir trabajando:** solo durante una terminación pendiente.
- **Configuración** (solo lectura en la v1): muestra los valores actuales y explica cómo cambiarlos (`sudo` + editar el archivo + volver a ejecutar el instalador si cambian los presets).
- **Salir.**

### Notificaciones

- Queda 1 minuto de pase.
- El pase terminó.
- La terminación pendiente se ejecutó.
- La sesión por tiempo terminó.
- La sesión arrancó al encender el Mac.

### Abrir al iniciar sesión

La app se abre sola al iniciar sesión en el Mac.

## Decisiones técnicas (de la investigación)

- **Framework:** SwiftUI `MenuBarExtra`. Objetivo: macOS 26+. `LSUIElement = YES`, para que no salga en el Dock.
- **Sin sandbox:** la app ejecuta `sudo` y lee `/var/db/efficiency-guardian/state`. No se va a publicar en la App Store.
- **Acciones:** `Process` con `/usr/bin/sudo -n /usr/local/sbin/guardian <comando>`, con argumentos **idénticos** a los de la regla de sudoers.
  - No necesita helper privilegiado ni `SMAppService.daemon`, y por tanto ninguno de sus problemas de firma.
- **Leer el estado:**
  - Ejecutar `guardian status --json`, o vigilar el archivo de estado con `DispatchSource` (eventos del sistema de archivos).
  - El reloj de la cuenta atrás se calcula en la app a partir de las horas de fin. No hace falta consultar el estado cada segundo.
- **Abrir al iniciar sesión:** `SMAppService.mainApp.register()`. **Verificar** que funciona con la firma local o gratuita. Si no, añadirla a mano en Ajustes → General → Ítems de inicio.
- **Firma:** "Sign to Run Locally" o Personal Team (Apple ID gratis). No hace falta cuenta de pago para este alcance: no hay extensión ni daemon dentro de la app.
- **Proyecto:** Xcode, en `app/` dentro del repositorio.
- **Fase 3 dentro de la app (decidir):** la app podría cerrar las pestañas ella misma en el instante en que cambia el estado, con su propio permiso de Automatización, y retirar el LaunchAgent.

## Fuera de la v1 (→ Fase 6)

- Interruptor en el Centro de control (`ControlWidgetToggle`; firma gratuita sin confirmar).
- Ventana de configuración editable. Debería pedir la contraseña de administrador al guardar, para conservar la fricción.
- Atajo de teclado global, sonidos, animaciones, pantalla de bienvenida.
- Estadísticas: tiempo enfocado, pases por día.
- Página propia de "bloqueado" en vez de cerrar pestañas.

## Verificación manual

- [ ] El ícono cambia en ≤2 s tras cada acción, y en ≤30 s tras los cambios que hace el LaunchDaemon (fin de pase o de sesión).
- [ ] Cada opción del menú funciona sin pedir contraseña.
- [ ] Las opciones no disponibles aparecen desactivadas y con el motivo.
- [ ] Las notificaciones llegan.
- [ ] La app se abre sola al iniciar sesión en el Mac.
- [ ] Tras reiniciar el Mac con `AUTOSTART_AT_BOOT=yes`, el ícono muestra la sesión indefinida.
