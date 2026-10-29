# efficiency-guardian

Interruptor de "modo enfoque" para macOS: bloquea las redes sociales que capturan la atención (YouTube, Facebook, Instagram, TikTok…) y conserva LinkedIn.

## Para agentes: empieza aquí

1. **Lee [PLAN.md](PLAN.md) antes de hacer nada.** Tiene el estado actual, las decisiones tomadas y el siguiente paso.
2. **Abre los documentos de `docs/` solo cuando el paso que vas a hacer los enlace.**
3. **No repitas la investigación que ya está en `docs/investigacion/`.** Si algo cambió o resultó falso, corrige el documento y anota la fecha.
4. **Al terminar:** actualiza "Estado actual" y la "Bitácora" en PLAN.md.

## Reglas del proyecto

- **Los comandos con `sudo` los ejecuta el usuario, no el agente.** Eso incluye instalar, desinstalar y probar el motor real. El agente prepara los scripts y explica qué hacen.
- **Durante el desarrollo, nunca editar `/etc/hosts` ni `/etc/sudoers.d/` directamente.** Las pruebas usan un archivo hosts temporal.
- **Idioma:** documentación, comentarios y mensajes del programa en español; nombres de archivos, funciones y comandos en inglés.
- **Pruebas:** `zsh tests/run.zsh` (sin root). Deben pasar antes de dar un paso por terminado; el instalador se niega a instalar si fallan.
- **Archivos de código cortos y con una sola responsabilidad: unas 100 líneas como máximo; 150 es inaceptable** (D13). El usuario debe poder depurar a mano leyendo un archivo completo.
  - Si un archivo se acerca a 100 líneas, divídelo **antes** de seguir añadiendo.
  - `tests/check-length.zsh` lo comprueba con cada ejecución de las pruebas.
  - No aplica a datos (`blocklists/`, `.plist`, configuración) ni a la documentación.
