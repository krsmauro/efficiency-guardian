# Fase 2: el interruptor (Concentración + Atajos)

> Requisito: la Fase 1 instalada y verificada. Casi todo aquí es **configuración manual en la interfaz de macOS**: no hay código. Las automatizaciones de Atajos no se pueden crear por línea de comandos, así que el agente guía y el usuario hace clic. Contexto: [02-integracion-macos.md](../investigacion/02-integracion-macos.md).

## Pasos

### 2.1 Crear un modo de Concentración dedicado
- Ajustes del Sistema → Concentración → "Añadir Concentración" → Personalizado → nombre: **Trabajo profundo** (o el que decida el usuario, D2).
- **Por qué uno nuevo:** si el bloqueo se ata a "No molestar", también se activaría de noche o en reuniones.
- **Decidir "Compartir entre dispositivos":** si está activado, activar la Concentración en el iPhone también la activa en el Mac y debería disparar el bloqueo. Verificarlo en 2.6.

### 2.2 Permitir scripts en Atajos
Atajos → Ajustes → Avanzado → activar **"Permitir ejecutar scripts"**.

### 2.3 Crear dos atajos
| Nombre | Acción | Contenido |
|---|---|---|
| `Guardian: bloquear` | Ejecutar script de shell (shell `zsh`, entrada: ninguna) | `sudo -n /usr/local/sbin/guardian start` |
| `Guardian: desbloquear` | Ejecutar script de shell | `sudo -n /usr/local/sbin/guardian stop` |

Probar cada uno a mano desde la app Atajos **y** desde la barra de menús. Hay un reporte de atajos que fallan solo desde la barra de menús.

### 2.4 Crear dos automatizaciones
Atajos → pestaña Automatización → "+" → Concentración → **Trabajo profundo**:

| Disparador | Modo | Ejecuta |
|---|---|---|
| "Cuando se activa" | **Ejecutar de inmediato** | `Guardian: bloquear` |
| "Cuando se desactiva" | **Ejecutar de inmediato** | `Guardian: desbloquear` |

### 2.5 Que el estado se vea (provisional)
- Ajustes del Sistema → Centro de control → Concentración → "Mostrar en la barra de menús": **cuando está activo**.
- **Es solo un indicador provisional.** Indica que la Concentración está activa, **no** que el bloqueo lo esté. Desde la Fase 4 hay sesiones que no dependen de la Concentración (por tiempo, al encender el Mac). El indicador real de estado será la app de barra de menús ([Fase 5](fase-5-app-barra-de-menus.md)).
- **Por eso esta fase no crea botones extra** (sesión por tiempo, pase, estado): esos controles vivirán en la app.
- **Mientras no exista la app** (con la Fase 4 instalada):
  - **Arrepentirse durante el retraso:** volver a activar la Concentración llama a `start`, que cancela la terminación pendiente. No hace falta un atajo para `cancel-stop`.
  - **Pase:** escribir `sudo -n /usr/local/sbin/guardian pass` en la Terminal. Escribirlo es fricción deseada.
  - **Estado:** `guardian status` en la Terminal.
- **Opcional (un clic):**
  - Crear el atajo `Alternar Trabajo profundo` con la acción "Definir Concentración" → Trabajo profundo → Alternar. Verificar que "Alternar" exista en el Mac; si no, usar "Activar".
  - Añadirlo al Centro de control con "Editar controles" → Atajos, o llevarlo a la barra de menús.

### 2.6 Matriz de pruebas
Anotar ✅ o ❌ en la bitácora de [PLAN.md](../../PLAN.md):

- [ ] Activar desde el Centro de control → YouTube bloqueado.
- [ ] Desactivar desde el Centro de control → YouTube desbloqueado (con la Fase 4, a los 5 min).
- [ ] Desactivar y volver a activar antes de 5 min → sigue bloqueado (la terminación se cancela).
- [ ] Activar con el atajo `Alternar` (si se creó).
- [ ] Activar por horario: crear un horario de prueba de 2 minutos.
- [ ] Activar desde el iPhone (si "Compartir entre dispositivos" está activado).
- [ ] Activar, poner el Mac en reposo, despertarlo y desactivar → ¿se desbloquea?
- [ ] Activar dos veces seguidas o un doble evento → sin errores (el motor es idempotente).

**Si alguna prueba falla:** anotarla. El LaunchDaemon de la [Fase 4](fase-4-sesiones-y-tiempo.md) reconcilia el estado cada 30 s, pero **no** puede saber si la Concentración está activa: ese archivo está protegido (ver [entorno.md](../entorno.md)). Un evento perdido de Atajos solo se corrige pulsando otra vez o desde la app.

**Con la Fase 4:** desactivar la Concentración llama a `guardian stop`, y por tanto **también respeta el retraso al terminar** (por defecto 5 min). Es intencional; ver D10 en [PLAN.md](../../PLAN.md).
