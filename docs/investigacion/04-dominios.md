# Investigación: lista de dominios a bloquear

> Investigado el 2026-10-28. `/etc/hosts` no acepta comodines, así que cada subdominio va explícito. El motor añade por su cuenta la línea `0.0.0.0` y la línea `::` de cada dominio.
>
> Cada grupo se convertirá en un archivo `blocklists/<grupo>.txt` (ver [fase-1-motor.md](../fases/fase-1-motor.md)). Los grupos permiten dar un "pase" a un solo sitio, por ejemplo solo YouTube.
>
> **Decisión D6 (usuario, 2026-10-28): se activan TODOS los grupos de abajo**, incluidos WhatsApp, Twitch y Pinterest. Los grupos `whatsapp`, `twitch` y `pinterest` se añadieron después de la investigación: **sus dominios son una propuesta sin investigar a fondo** y hay que verificarlos en el paso 1.6.

## Nunca bloquear

| Dominio | Por qué |
|---|---|
| `linkedin.com`, `lnkd.in` y cualquier dominio de LinkedIn | Requisito del usuario |
| `accounts.youtube.com` | El inicio de sesión de Google pasa por ahí (`/accounts/SetSID`). Bloquearlo cuelga el login de Gmail, Drive y Meet. |
| `youtube.googleapis.com` | El reproductor de video de Google Drive lo necesitaría (reporte antiguo, confianza media) |
| `studio.youtube.com`, `upload.youtube.com` | **D6b: el usuario usa YouTube Studio para trabajar.** Verificar en 1.6 que Studio funciona con `www.youtube.com` bloqueado. Si alguna parte depende de él (por ejemplo, la vista previa del video), anotarlo y usar un pase. |
| `t.co` | Rompería los enlaces acortados en correos y newsletters |
| `fbcdn.net` y subdominios | Nombres aleatorios (no se pueden listar). Además lo usa WhatsApp Web, aunque ahora WhatsApp también se bloquea. |

## Grupos propuestos

### `youtube` (confirmado por el usuario)
```
youtube.com
www.youtube.com
m.youtube.com
music.youtube.com
tv.youtube.com
youtu.be
youtube-nocookie.com
www.youtube-nocookie.com
youtubekids.com
www.youtubekids.com
youtubei.googleapis.com
```
- **Opcional:** `i.ytimg.com` (miniaturas). Quita las miniaturas de YouTube que aparecen en otros sitios.
- **Efecto esperado:** los videos de YouTube incrustados en Google Docs o Slides tampoco cargarán.
- El video en sí viene de `*.googlevideo.com`, con nombres aleatorios que no se pueden listar. No hace falta: sin la página no hay video.

### `facebook` (confirmado por el usuario)
```
facebook.com
www.facebook.com
m.facebook.com
web.facebook.com
mbasic.facebook.com
fb.com
www.fb.com
fb.me
fb.watch
```
- **Opcional:** `connect.facebook.net`. Solo rompe los botones de Facebook y el "Iniciar sesión con Facebook" en otros sitios.
- `messenger.com` **no** está incluido (es mensajería). Preguntar si se quiere añadir.

### `instagram` (confirmado por el usuario)
```
instagram.com
www.instagram.com
i.instagram.com
graph.instagram.com
instagr.am
ig.me
static.cdninstagram.com
```

### `tiktok` (confirmado por el usuario)
```
tiktok.com
www.tiktok.com
m.tiktok.com
vm.tiktok.com
vt.tiktok.com
```
- Las CDN de TikTok (tiktokcdn, ttwstatic) usan nombres aleatorios. Bloquear la web es suficiente.

### `x` (confirmado)
```
x.com
www.x.com
mobile.x.com
api.x.com
twitter.com
www.twitter.com
mobile.twitter.com
api.twitter.com
abs.twimg.com
pbs.twimg.com
video.twimg.com
platform.twitter.com
```
- **No incluir `t.co`.** Rompería los enlaces acortados en correos y newsletters.

### `reddit` (confirmado; ojo: también corta los resultados de Reddit en búsquedas técnicas, y en ese caso se usa un pase)
```
reddit.com
www.reddit.com
old.reddit.com
new.reddit.com
sh.reddit.com
m.reddit.com
np.reddit.com
gql.reddit.com
oauth.reddit.com
redd.it
i.redd.it
v.redd.it
preview.redd.it
external-preview.redd.it
www.redditstatic.com
www.redditmedia.com
```

### `threads` (confirmado)
```
threads.com
www.threads.com
threads.net
www.threads.net
```
- Threads se mudó a `threads.com` el 2025-04-24.

### `whatsapp` (confirmado; dominios sin investigar a fondo)
```
whatsapp.com
www.whatsapp.com
web.whatsapp.com
wa.me
```
- **Solo afecta al Mac:** el teléfono sigue recibiendo mensajes con normalidad. La app de escritorio de WhatsApp no está instalada (2026-10-28); si se instala, usa otros dominios (`*.whatsapp.net`) y habría que revisarlo.
- **Verificar en 1.6:** que WhatsApp Web no carga con el bloqueo activo y sí carga sin él.

### `twitch` (confirmado; dominios sin investigar a fondo)
```
twitch.tv
www.twitch.tv
m.twitch.tv
clips.twitch.tv
player.twitch.tv
gql.twitch.tv
```

### `pinterest` (confirmado; dominios sin investigar a fondo)
```
pinterest.com
www.pinterest.com
co.pinterest.com
es.pinterest.com
pinterest.es
pin.it
i.pinimg.com
s.pinimg.com
```
- Pinterest redirige a un subdominio por país (`co.`, `es.`, …). **Verificar en 1.6** a cuál redirige en esta Mac y añadirlo si falta.
- Bloquear `i.pinimg.com` también quita las imágenes de Pinterest dentro de la vista previa de Google Imágenes.

## Listas mantenidas por otros (para revisar la nuestra de vez en cuando)

- [AdGuard HostlistsRegistry / services](https://github.com/AdguardTeam/HostlistsRegistry/tree/main/services): por servicio, con comodines. `youtube.yml` se actualizó en junio de 2026.
- [nextdns/services](https://github.com/nextdns/services): por servicio.
- **No usar tal cual** la extensión "social" de StevenBlack/hosts: **bloquea LinkedIn y WhatsApp**, no incluye YouTube y no tiene líneas IPv6.

## Cómo verificar la lista (Fase 1)

- **Por cada dominio, con el bloqueo activo:** `dscacheutil -q host -a name <dominio>` solo debe mostrar `0.0.0.0` y `::`, sin ninguna IP real.
- **En el navegador, con el bloqueo activo, deben seguir funcionando:**
  - Iniciar sesión en Google (abrir una ventana privada e iniciar sesión).
  - Gmail, Drive (incluido un video en Drive) y Meet.
  - LinkedIn.
  - YouTube Studio.
- **En el navegador, con el bloqueo activo, NO deben cargar:**
  - Cada grupo, incluido WhatsApp Web.
