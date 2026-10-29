# Plan: efficiency-guardian

## Objetivo

Un "modo enfoque" para el MacBook Pro que bloquea en **todos los navegadores** los sitios que capturan la atención:
- YouTube, Facebook, Instagram, TikTok, X, Reddit, Threads, Twitch, Pinterest y WhatsApp Web.
- LinkedIn y YouTube Studio se conservan.

**Formas de usarlo:**
- **Sesión indefinida:** arranca sola al encender el Mac (configurable) y termina al apagarlo.
- **Sesión por tiempo:** 25, 50 o 90 min (configurable).
- **Concentración nativa:** también se activa con el modo de Concentración de macOS.

**Válvulas de escape con fricción, todas configurables:**
- **Pase temporal** para YouTube: 5 min, máximo 3 por sesión.
- **Retraso al terminar:** el bloqueo sigue 5 min más tras pedir terminar, para poder arrepentirse.
- **Candado opcional** en las sesiones por tiempo.

**Interfaz:** una app de barra de menús en Swift que muestra siempre el estado. Debajo hay un motor de línea de comandos que el usuario no necesita escribir.

## Estado actual

- **Fase:** planificación terminada, con todas las decisiones tomadas salvo tres supuestos por confirmar (S1, S2 y S3, en D10). No bloquean la Fase 1.
- **Siguiente paso:** un agente implementa la [Fase 1](docs/fases/fase-1-motor.md).
- **Código escrito:** ninguno. `/etc/hosts` sigue con las 4 líneas manuales de YouTube.
- **Última actualización:** 2026-10-29.

## Cómo usar este plan (agentes)

- **Este archivo es el índice.** Abre los documentos enlazados solo cuando el paso que vas a hacer los necesite.
- **Dónde está cada cosa:**
  - Hechos de la máquina: [docs/entorno.md](docs/entorno.md).
  - Investigación ya hecha (no la repitas): [docs/investigacion/](docs/investigacion/).
  - Especificaciones por fase: [docs/fases/](docs/fases/). Cada fase tiene la suya; la tabla "Fases" dice si está lista o es un borrador.
- **Al terminar una sesión:**
  - Actualiza "Estado actual" y marca los pasos hechos.
  - Añade una entrada a la "Bitácora".
  - Si algo de la investigación resultó falso, corrígelo en su documento y anota la fecha.
- **Los comandos con `sudo` los ejecuta el usuario, no el agente.**

## Arquitectura

```
  App de barra de menús (Swift, Fase 5) ─┐
  Concentración "Trabajo profundo"      ─┤  sudo -n guardian start [min] | stop | cancel-stop | pass
     + automatizaciones de Atajos (F2)  ─┘        │ (regla sudoers, argumentos exactos)
                                                  ▼
  LaunchDaemon cada 30 s (F4) ──▶  /usr/local/sbin/guardian  (zsh, root) ◀── estado + configuración
     reconcile: fin de pase,              │ reescribe SOLO su bloque
     fin de sesión, arranque              ▼
                                   /etc/hosts  →  todos los navegadores y apps
                                          ▲ lee el bloque (sin root)
  LaunchAgent de usuario cada 15 s (F3) ──┘ cierra las pestañas abiertas de dominios bloqueados
```

## Decisiones

| ID | Decisión | Estado | Por qué (detalle en el enlace) |
|---|---|---|---|
| D1 | Bloquear con `/etc/hosts`, con **2 líneas por dominio, IPv4 e IPv6** (`0.0.0.0` y `::`) | ✅ | Cubre los 5 navegadores, incluido Thorium. Chromium lo respeta incluso con DNS seguro. Gratis. La línea IPv6 cierra la fuga que tenía el bloqueo manual. → [01](docs/investigacion/01-metodos-de-bloqueo.md) |
| D2 | Activar también con un modo de Concentración **nativo y dedicado** ("Trabajo profundo") + automatizaciones de Atajos | ✅ | Es el botón que el usuario ya usa. Sin código. → [02](docs/investigacion/02-integracion-macos.md) |
| D3 | Motor en **zsh**; interfaz en **Swift** | ✅ | El motor corre como root: necesita un intérprete del sistema y cero dependencias. Swift es lo único que da una interfaz nativa de barra de menús. → [02](docs/investigacion/02-integracion-macos.md#por-qué-el-motor-es-un-script-zsh-y-no-typescript-o-python) |
| D4 | Permisos de root con una regla de sudoers de **argumentos exactos**, más un LaunchDaemon para lo que depende del tiempo | ✅ | Simple, sin helper privilegiado ni firma de pago. → [02](docs/investigacion/02-integracion-macos.md#cómo-dar-permisos-de-root-sin-contraseña) |
| D5 | **Pase temporal:** 5 min y máximo 3 por sesión, configurables. Por defecto solo para YouTube. | ✅ usuario | → [fase 4](docs/fases/fase-4-sesiones-y-tiempo.md) |
| D6 | Grupos bloqueados: YouTube, Facebook, Instagram, TikTok, X, Reddit, Threads, Twitch, Pinterest y WhatsApp | ✅ usuario | Los dominios de WhatsApp, Twitch y Pinterest están sin investigar a fondo: se verifican en 1.6. → [04](docs/investigacion/04-dominios.md) |
| D6b | **YouTube Studio no se bloquea** | ✅ usuario | Lo usa para trabajar |
| D7 | ~~"YouTube sin trampas" (ocultar el feed y los Shorts)~~ | ❌ descartado | Solo es posible con una extensión de navegador, y el usuario no quiere ampliar el alcance |
| D8 | iPhone | ⛔ fuera de alcance | |
| D9 | ¿Construir o comprar? | ✅ construir | Ninguna herramienta cubre Brave y Thorium y además la Concentración nativa. → [03](docs/investigacion/03-herramientas-existentes.md) |
| D10 | Dos tipos de sesión, **por tiempo** e **indefinida**. Al pedir terminar, el bloqueo sigue `STOP_DELAY_MINUTES` (5) y se puede cancelar. Candado completo opcional en las sesiones por tiempo (`TIMED_LOCK`, desactivado por defecto). | ✅ usuario, **con supuestos S1, S2 y S3 por confirmar** | S1: el retraso también aplica a la sesión indefinida y a desactivar la Concentración. S2: pedir una sesión por tiempo con una indefinida en curso la convierte, conservando los pases. S3: como el Mac casi nunca se apaga (duerme), una sesión indefinida puede durar días, así que el contador de pases se reiniciaría cada día. → [fase 4](docs/fases/fase-4-sesiones-y-tiempo.md#supuestos-que-tomé-y-el-usuario-debe-confirmar) |
| D11 | Sesión indefinida **automática al encender** (`AUTOSTART_AT_BOOT`, **activada por defecto**). Termina al apagar el Mac. | ✅ usuario | El fin se detecta al **siguiente arranque**, con `kern.bootsessionuuid`, que es más fiable que engancharse al apagado |
| D12 | Interfaz v1: **app de barra de menús en Swift**. La "experiencia asombrosa" se investiga y se pule después (Fase 6). | ✅ usuario | → [fase 5](docs/fases/fase-5-app-barra-de-menus.md) |
| D13 | **Archivos de código con una sola responsabilidad y unas 100 líneas como máximo (150 es inaceptable).** Lo comprueba `tests/check-length.zsh`. | ✅ usuario | Permite depurar a mano. El motor se divide en `bin/guardian` (entrada) + módulos en `lib/`. Como el motor corre como root, los módulos se cargan solo desde una ruta fija de root. → [fase 1](docs/fases/fase-1-motor.md#regla-de-tamaño-d13-requisito-del-usuario) |

## Fases

| Fase | Qué | Especificación |
|---|---|---|
| 1 | Motor de bloqueo (`start`/`stop`/`status`, IPv6, grupos, instalador) | ✅ [lista](docs/fases/fase-1-motor.md) |
| 2 | Concentración + Atajos como interruptor | ✅ [lista](docs/fases/fase-2-interruptor.md) (manual, guiada) |
| 3 | Cerrar las pestañas abiertas de sitios bloqueados | 📝 [borrador](docs/fases/fase-3-cerrar-pestanas.md) (prototipo de permisos primero) |
| 4 | Sesiones por tiempo e indefinidas, retraso al terminar, arranque automático, pases | 📝 [borrador](docs/fases/fase-4-sesiones-y-tiempo.md) |
| 5 | App de barra de menús en Swift (v1) | 📝 [borrador](docs/fases/fase-5-app-barra-de-menus.md) |
| 6 | Investigar y pulir la experiencia de usuario | ⏳ se escribe al llegar |

### Fase 1: motor de bloqueo
- [ ] 1.1 Crear `blocklists/*.txt` a partir de [04-dominios.md](docs/investigacion/04-dominios.md): los 10 grupos de D6.
- [ ] 1.2 Escribir las pruebas primero: una por módulo en `tests/`, el fixture y `check-length.zsh` (D13).
- [ ] 1.3 Escribir `bin/guardian` y los módulos de `lib/` hasta que pasen las pruebas.
- [ ] 1.4 Escribir `install.sh` (con sus pasos en `install/`) y `uninstall.sh`.
- [ ] 1.5 **Usuario:** revisar los scripts y ejecutar `sudo ./install.sh`.
- [ ] 1.6 **Usuario:** verificación manual (checklist en la especificación, incluidos YouTube Studio, WhatsApp Web y Pinterest).

### Fase 2: el interruptor
- [ ] 2.1–2.5 Configurar la Concentración, los atajos y las automatizaciones (manual, guiado).
- [ ] 2.6 Matriz de pruebas.

### Fase 3: cerrar pestañas
- [ ] 3.1 Prototipo: ¿un LaunchAgent puede controlar los navegadores (permisos de Automatización)?
- [ ] 3.2 Pruebas de la lógica (host de una URL → cerrar o no).
- [ ] 3.3 Script `close-tabs` (JXA) + LaunchAgent + instalador.
- [ ] 3.4 Verificación manual en los 5 navegadores.

### Fase 4: sesiones, tiempo y pases
- [ ] 4.0 **Usuario:** confirmar los supuestos S1, S2 y S3.
- [ ] 4.1 Configuración (`config.default`, lectura validada) y archivo de estado.
- [ ] 4.2 `start <min>`, `stop` con retraso, `cancel-stop`, `pass`, `status --json` y `reconcile`, con pruebas (reloj y arranque falsos).
- [ ] 4.3 LaunchDaemon `reconcile` cada 30 s + regla de sudoers generada desde la configuración.
- [ ] 4.4 Verificación manual: reinicio, reposo, pase, retraso, candado.
- [ ] 4.5 Tras 1–2 semanas de uso, revisar los registros y ajustar los valores por defecto.

### Fase 5: app de barra de menús (v1)
- [ ] 5.1 Proyecto Xcode en `app/` con `MenuBarExtra` (sin sandbox, `LSUIElement`).
- [ ] 5.2 Leer el estado y mostrarlo en el ícono y el menú.
- [ ] 5.3 Acciones mediante `sudo -n guardian …`.
- [ ] 5.4 Notificaciones y apertura al iniciar sesión.
- [ ] 5.5 Decidir si la app absorbe la Fase 3.
- [ ] 5.6 Verificación manual.

### Fase 6: experiencia de usuario
Investigar referencias, definir qué es una experiencia "asombrosa" para el usuario, prototipar y probar. Candidatos (detalle en la [especificación de la Fase 5](docs/fases/fase-5-app-barra-de-menus.md#fuera-de-la-v1--fase-6)):
- Interruptor en el Centro de control.
- Ventana de configuración.
- Estadísticas.
- Página propia de "bloqueado".

## Riesgos conocidos

- **El usuario es administrador:** siempre puede deshacer el bloqueo (cambiar la hora, editar la configuración, desinstalar). **El objetivo es añadir fricción, no seguridad.**
- **Hay formas de saltarse hosts:**
  - Proxies, las ventanas Tor de Brave, la VPN integrada de Vivaldi.
  - Quizá Safari con iCloud Private Relay (sin confirmar).
- **Las automatizaciones de Atajos** tienen casos de fiabilidad sin confirmar en el Mac: activación desde el iPhone, por horario, tras reposo. Se prueban en 2.6.
- **Las listas de dominios envejecen:** revisarlas de vez en cuando contra AdGuard y NextDNS ([04](docs/investigacion/04-dominios.md)).
- **YouTube Studio** podría depender en parte de `www.youtube.com` (sin verificar). Si es así, se usa un pase.

## Preguntas sin verificar (resolverlas al llegar a la fase)

- ¿Existe la opción "Alternar" en la acción "Definir Concentración" en el Mac? (Fase 2)
- ¿Un LaunchAgent con `osascript` obtiene permiso de Automatización, o falla en silencio? (Fase 3)
- ¿launchd ejecuta `reconcile` en cuanto el Mac despierta? (Fase 4)
- ¿Funciona `SMAppService.mainApp` (abrir al iniciar sesión) con la firma local o gratuita? (Fase 5)

## Bitácora

### 2026-10-28 · Sesión 1: exploración y plan
- **Hecho:**
  - Investigación de métodos de bloqueo, integración con macOS y herramientas existentes (3 agentes en paralelo).
  - Pruebas de solo lectura en la Mac.
  - Este plan y las especificaciones de las Fases 1 a 5.
- **Hallazgos clave:**
  - El bloqueo manual actual **tiene una fuga por IPv6** y deja sin bloquear `music.youtube.com`.
  - Chromium respeta hosts incluso con DNS seguro.
  - Las automatizaciones de Atajos por Concentración existen en el Mac desde macOS 26.
  - Focus Filters no es fiable en el Mac.
  - El archivo de estado de Concentración está protegido.
  - **No bloquear `accounts.youtube.com`**, porque rompe el inicio de sesión de Google.
  - Las pestañas abiertas sobreviven al bloqueo; de ahí la Fase 3.
  - `kern.bootsessionuuid` existe.
  - Thorium tiene diccionario AppleScript.
- **Decisiones del usuario, primera ronda:**
  - D5: pase de 5 min, máximo 3 por sesión, configurables.
  - D6: también X, Reddit, Threads, Twitch, Pinterest y WhatsApp.
  - D6b: conservar YouTube Studio.
- **Decisiones del usuario, segunda ronda:**
  - D7 descartado (no ampliar el alcance con extensiones).
  - D10: sesiones por tiempo e indefinidas, retraso de 5 min al terminar, candado configurable.
  - D11: arranque automático, activado por defecto.
  - D12: app de barra de menús en Swift ahora; la UX se pule después.
- **Cambios:**
  - Comandos renombrados de `on`/`off` a `start`/`stop`.
  - La especificación del pase se integró en la Fase 4 (sesiones y tiempo).
  - La Fase 0 (Unhook) se eliminó.

### 2026-10-29 · Sesión 1 (continuación): regla de tamaño
- **Requisito del usuario (D13):** archivos de código de una sola responsabilidad, con unas 100 líneas como máximo; 150 es inaceptable.
- **Aplicado:**
  - En CLAUDE.md, como regla para todos los agentes.
  - En las especificaciones de las Fases 1, 3, 4 y 5, con la lista de módulos de cada una.
- **Consecuencia de seguridad:** el motor ahora carga módulos siendo root. Por eso solo se cargan desde `/usr/local/libexec/efficiency-guardian/lib` (de root) y el instalador verifica toda la cadena de permisos.
- **Aclaración del usuario:** pensaba sobre todo en la interfaz (Swift), y aceptaba un motor de un solo archivo si la seguridad lo exigía.
- **Se mantiene la regla también para el motor**, porque la seguridad no lo exige:
  - Un solo archivo depende de los mismos permisos de carpeta que los módulos.
  - La carga desde una ruta fija ya cubre la diferencia.
  - El motor crecerá a unas 500–600 líneas con la Fase 4 (estimación), justo donde más importa poder depurar a mano.
  - No reabrir sin un motivo nuevo.
