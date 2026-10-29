# Investigación: herramientas existentes (¿construir o comprar?)

> Investigado el 2026-10-28. Precios en US$. Antes de reabrir la pregunta de comprar una herramienta, lee esto.

## Conclusión

**Construir, pero pequeño:** un script + Atajos, una o dos sesiones de trabajo. Razones:

1. **El usuario usa 4 navegadores Chromium a diario** (Brave, Vivaldi, Chrome, Thorium).
   - Casi todas las herramientas funcionan integrándose con navegadores concretos y **ninguna lista Thorium**.
   - Cold Turkey **bloquearía Thorium entero** por no estar soportado.
   - `/etc/hosts` cubre todos los navegadores sin integrarse con ninguno.
2. **Ninguna herramienta madura se conecta de forma fiable con la Concentración nativa del Mac.**
   - Raycast y Jomo dicen tener Focus Filter, pero la API de Focus Filters es poco fiable en el Mac (ver [02-integracion-macos.md](02-integracion-macos.md)).
   - Las automatizaciones de Atajos de macOS 26 pueden llamar a cualquier herramienta con línea de comandos. Esa es la pieza que vamos a usar nosotros.
3. **El "pase temporal" para YouTube** (desbloquear 15 minutos para algo legítimo y volver a bloquear solo) resuelve el problema exacto de [conversation.txt](../../conversation.txt). Raycast tiene algo parecido (posponer 1–10 min), pero no cubre Brave ni Thorium con seguridad.

**Lo que las herramientas hacen mejor y nosotros no:**
- Resistir que uno mismo deshaga el bloqueo (Cold Turkey, SelfControl, modo bloqueado de Freedom).
- Cubrir varios dispositivos (Freedom, Jomo).
- Seguir funcionando cuando cambian los navegadores.

Si en el futuro el problema es "me salto mi propio bloqueo", reconsiderar **Cold Turkey Pro** (pago único de unos US$39) o el modo con candado propio (Fase 4).

## Bloqueadores para Mac

| Herramienta | Estado 2026 | Precio | Cómo bloquea | Automatización | Cancelar | Notas |
|---|---|---|---|---|---|---|
| Raycast Focus | v2.4, sep. 2026, soporta macOS 27 | Gratis | Lee la URL del navegador (Safari, Chrome, Vivaldi; **Brave y Thorium sin confirmar**) | `raycast://focus/toggle`, Atajos, Focus Filter (sin confirmar en v2) | Fácil (posponer) | No está instalado en esta Mac |
| Jomo | v2.1.0, oct. 2026 | US$29.99/año o US$99.99 de por vida | Integración con navegadores (sin Vivaldi ni Thorium) | Atajos, Focus Filter | Media | Sincroniza Mac + iPhone |
| Cold Turkey Pro | v4.9.x | ~US$39 una vez | Extensiones; **bloquea los navegadores que no soporta** | Línea de comandos (`-start/-stop/-toggle`) | Muy difícil | El más resistente |
| SelfControl | **Última versión en 2021**, código abierto (GPL‑3) | Gratis | hosts + pf | Solo línea de comandos | **Imposible antes de que acabe el tiempo** | Justo el problema que tuvo el usuario |
| Freedom | v2.26 | US$40/año | Proxy local (todos los navegadores) | Menú, horarios; **sin Atajos** | Modo bloqueado | El mejor multiplataforma |
| Focus (heyfocus) | Sin actualizaciones desde ago. 2025 | US$49 | Integración con navegadores | URLs `focus://`, scripts | Opcional | Riesgo de abandono |
| 1Focus, Opal, one sec | Activos | Gratis a US$100/año | Navegadores concretos | Sin Atajos | Variable | No aportan nada clave |

## YouTube "sin trampas": bloqueo parcial

> **Descartado por el usuario (D7, 2026-10-28):** solo se puede hacer con una extensión de navegador, y el usuario no quiere ampliar el alcance. Se conserva la investigación por si cambia de idea.

Sirve para usar YouTube (buscar un video concreto) sin el feed, los Shorts ni las recomendaciones. Es complementario al bloqueo total durante el modo enfoque.

| Opción | Dónde funciona | Notas |
|---|---|---|
| **Unhook** (extensión) | Chrome, Brave, Vivaldi, Thorium | Gratis, v1.6.9 (mar. 2026), 1M de usuarios, formato MV3. Oculta el feed, la barra lateral, Shorts, comentarios y pantallas finales, y apaga la reproducción automática. Algunas reseñas dicen que se rompió en parte a finales de 2025; existe el fork "Unhook NG". **No existe para Safari.** |
| Reglas propias en **Brave Shields** | Brave, sin extensión | `brave://settings/shields/filters`. Ejemplos: `youtube.com##ytd-browse[page-subtype="home"] #primary`, `youtube.com##ytd-reel-shelf-renderer`, `youtube.com###secondary`. Se rompen cuando YouTube cambia su HTML. |
| uBlock Origin Lite | Chromium y **Safari** (macOS 15+) | Acepta reglas propias para ocultar elementos desde mediados de 2025. |
| **Pausar el historial de YouTube** | Todas las cuentas y dispositivos | **El feed de inicio queda en blanco.** Confirmado de nuevo en abril de 2026. Puede no aplicar si la cuenta ya tiene mucho historial, y no quita las sugerencias junto al video. Se pierde el historial y el punto donde se dejó cada video. |
| LeechBlock NG | Chromium | Puede bloquear youtube.com pero permitir `/watch` y `/results`, o mostrar una cuenta regresiva antes de entrar. Solo cubre un navegador y se desactiva en dos clics. |

Opciones descartadas:
- **DF Tube:** abandonado en 2019 y con formato MV2, ya no funciona en Chromium.
- **BlockSite:** quejas por recolección de datos.
- **uBlock Origin clásico:** Chrome lo retiró de su tienda el 2026-08-31.

## Código abierto del que se puede aprender

- **[iloveitaly/hyper-focus](https://github.com/iloveitaly/hyper-focus)** (Swift, MIT, activo):
  - Bloquea por ruta (por ejemplo `/shorts` sí, `/watch` no) leyendo la URL del navegador.
  - Tiene una API HTTP local (`/pause`, `/override`) que un atajo puede llamar.
  - Es el mejor modelo si algún día se quiere bloquear por ruta.
- **[SelfControl](https://github.com/SelfControlApp/selfcontrol)** (GPL‑3): referencia de cómo escribe `/etc/hosts` (formato `0.0.0.0` + `::`).
- **[raviriley/Willpower](https://github.com/raviriley/Willpower)**: documenta que bloquear youtube.com con comodín rompe el inicio de sesión de Google, y que iCloud Private Relay se salta hosts.
- Ningún proyecto conecta bloqueo + Concentración nativa vía Atajos de forma reutilizable. Lo haremos nosotros.
