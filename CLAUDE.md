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
- **Idioma:** documentación y comentarios en español; nombres de archivos, funciones y comandos en inglés.
