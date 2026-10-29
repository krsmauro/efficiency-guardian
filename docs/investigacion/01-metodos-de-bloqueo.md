# Investigación: cómo bloquear sitios en macOS

> Investigado el 2026-10-28 (macOS 27.0). Confianza: **alta** = código fuente, documentación oficial o prueba en esta Mac; **media** = varias fuentes de la comunidad; **baja** = un solo reporte o inferencia.

## Resumen

- **Elegido: `/etc/hosts`**, con **dos líneas por dominio** (`0.0.0.0 dominio` y `:: dominio`) dentro de un bloque delimitado por marcadores.
- **Por qué:** bloquea a nivel de sistema, así que cubre a la vez los 5 navegadores del usuario, incluido Thorium, que casi ninguna herramienta comercial soporta. Es gratis, no necesita cuenta de desarrollador y se puede activar desde un script.
- **Descartados:** firewall `pf`, Tiempo en pantalla (Screen Time) y Network Extension.
- **Aplazado:** NextDNS, solo si algún día hay que cubrir también el iPhone.

| Método | ¿Cubre todos los navegadores? | ¿Se activa por script? | Costo | Veredicto |
|---|---|---|---|---|
| `/etc/hosts` | Sí (Chromium lo respeta incluso con DNS seguro; Safari, ver abajo) | Sí, como root | Gratis | **Elegido** |
| Extensión de navegador (LeechBlock, etc.) | No, hay que instalarla en cada uno y se salta abriendo otro navegador | No | Gratis | Solo como capa extra para YouTube |
| Tiempo en pantalla (sitios restringidos) | No, oficialmente solo Safari | No | Gratis | Descartado |
| Firewall `pf` por IP | Sí | Sí | Gratis | Descartado: YouTube comparte IPs con Gmail y Meet |
| NextDNS (DNS en la nube) | Sí, pero hay que configurar el DNS seguro en cada navegador Chromium | Sí (API beta) | Gratis hasta 300k consultas/mes; Pro US$19.90/año | Aplazado (útil para iPhone) |
| Network Extension (como Freedom u Opal) | Sí | Sí | Cuenta de desarrollador de pago (US$99/año) | Descartado: demasiado pesado |

## `/etc/hosts` en detalle

### Los navegadores Chromium lo respetan, incluso con "DNS seguro" (confianza alta)

- Chrome, Brave, Vivaldi y Thorium consultan `/etc/hosts` **antes** que el DNS seguro (DoH), tanto en modo automático como con un proveedor personalizado.
- Fuente: código de Chromium, `net/dns/host_resolver_manager.cc` (`CreateTaskSequence` añade la consulta a HOSTS antes que DoH) y `net/dns/dns_config_watcher_mac.cc`.
- Con una VPN que configura DNS dividido, Chromium usa el resolvedor del sistema, que también lee hosts.

### Excepciones: lo que **sí** se salta hosts

- Cualquier cosa que resuelva nombres en otra máquina:
  - Proxies SOCKS5 o HTTP, y extensiones de proxy ([doc de Chromium](https://chromium.org/developers/design-documents/network-stack/socks-proxy)).
  - Las ventanas Tor de Brave y la VPN integrada de Vivaldi (Proton VPN, añadida en marzo de 2025). Esto es inferencia, sin probar (confianza baja).
- **Safari con iCloud Private Relay: no confirmado (confianza baja).**
  - Un usuario reportó que Safari cargaba facebook.com a pesar de hosts, de forma intermitente, en macOS 15.
  - Los usuarios de Pi‑hole reportan que Private Relay se salta el DNS local.
  - Desde 2024, la navegación privada de Safari usa DNS cifrado propio.
  - El usuario casi no usa Safari (último uso: 2026-10-08), así que es un riesgo bajo. Probarlo en la Fase 1.
- Fuentes: [MacRumors](https://forums.macrumors.com/threads/safari-ignoring-hosts-file.2445512/), [Pi‑hole](https://discourse.pi-hole.net/t/icloud-private-relay/49811), [WebKit](https://webkit.org/blog/15697/private-browsing-2-0/).

### IPv6: hace falta una segunda línea por dominio (confianza alta, probado en esta Mac)

- Con solo `0.0.0.0 youtube.com`, macOS **sigue preguntando la IPv6 al DNS real** (ver [entorno.md](../entorno.md)). En una red con IPv6, el sitio carga.
- Chromium no tiene esta fuga, pero Safari y otras apps sí ([reporte de 2022](https://forums.macrumors.com/threads/etc-hosts-equivalent-for-ipv6.2361443/)).
- **Solución:** escribir `0.0.0.0 dominio` **y** `:: dominio`. SelfControl hace exactamente eso ([HostFileBlocker.m](https://github.com/SelfControlApp/selfcontrol/blob/master/Block%20Management/HostFileBlocker.m)).
- Usar `::` y no `::1`, por si algún día hay un servidor local escuchando en el puerto 80 o 443.

### Cuándo hace efecto el bloqueo (confianza media‑alta)

1. **Chromium detecta el cambio en `/etc/hosts` por sí mismo** y vacía su caché DNS. Sin eso, la caché dura unos 60 s.
2. **Las conexiones ya abiertas siguen funcionando.**
   - Chromium mantiene vivas las conexiones HTTP/2 y QUIC a youtube.com aunque cambie el DNS, y una visita nueva puede reutilizarlas.
   - **Las pestañas abiertas siguen reproduciendo video**, porque el video viene de `rr*---sn-*.googlevideo.com`, nombres aleatorios que no se pueden listar en hosts.
3. **Receta práctica tras activar:**
   - Vaciar la caché DNS del sistema: `dscacheutil -flushcache; killall -HUP mDNSResponder`.
   - **Cerrar las pestañas de sitios bloqueados.** Se puede hacer con AppleScript en Safari, Chrome, Brave y Vivaldi; en Thorium es probable pero no está probado.
   - Si aún carga, usar "Flush socket pools" en `chrome://net-internals/#sockets` o reiniciar el navegador.

### Sin comodines

`/etc/hosts` no acepta `*.youtube.com`, así que hay que listar cada subdominio. La lista propuesta está en [04-dominios.md](04-dominios.md).

### No romper Google

**No bloquear `accounts.youtube.com`.** El inicio de sesión de Google pasa por `accounts.youtube.com/accounts/SetSID` y se cuelga sin él ([reporte](https://www.googlecloudcommunity.com/gc/Workspace-Q-A/SSO-Google-Login-hangs-at-accounts-youtube-com-accounts-SetSID/m-p/886188)). Como hosts bloquea nombres exactos, basta con no incluirlo en la lista. Un bloqueo por DNS que cubre todos los subdominios (NextDNS) sí lo rompería.

## Tiempo en pantalla (Screen Time)

- **Las restricciones web son oficialmente solo para Safari** (confianza media). La guía de macOS 27 las pone bajo "Safari" ([Apple](https://support.apple.com/guide/mac-help/mchlbcf0dfe2/mac)).
- **No se pueden activar por script** (confianza media‑alta). La API de Tiempo en pantalla (FamilyControls) es solo para iOS, iPadOS y Mac Catalyst. Atajos no tiene acciones para ella.
- Un perfil de configuración (`ParentalControlsContentFilter`) puede cargar la lista, pero instalarlo requiere un clic manual en Ajustes.
- Veredicto: no sirve como interruptor.

## Firewall `pf` (bloqueo por IP)

Descartado (confianza alta):

- YouTube, Meet y Google comparten rangos de IP. Medido hoy: `www.youtube.com → 142.251.154.4`, `meet.google.com → 142.251.154.5`.
- SelfControl evita bloquear por IP los dominios de Google por esta misma razón ([BlockManager.m](https://github.com/SelfControlApp/selfcontrol/blob/master/Block%20Management/BlockManager.m)).

## NextDNS (DNS en la nube)

Aplazado:

- **Precio:** gratis hasta 300 000 consultas/mes; pasado el límite **sigue resolviendo pero deja de bloquear**. Pro: US$1.99/mes o US$19.90/año ([precios](https://nextdns.io/pricing)).
- **Bloqueo por servicio:** "Control parental → Servicios" tiene YouTube, TikTok, Instagram, Facebook, X y Reddit. No tiene Threads.
- **Activable por API (beta):** `PATCH /profiles/:id/parentalControl/services/youtube {"active":true|false}` con la cabecera `X-Api-Key` ([API](https://nextdns.github.io/api/)).
- **Ventaja:** cubre también el iPhone con el mismo perfil.
- **Problemas:**
  - En cada uno de los 4 navegadores Chromium hay que poner la URL del perfil NextDNS como DNS seguro, o desactivar su DNS integrado. Si no, se lo saltan ([NextDNS help](https://help.nextdns.io/t/60hl37w/chrome-secure-dns-easily-bypass-nextdns)).
  - iCloud Private Relay también se lo salta.
  - Su lista de YouTube incluye `youtube.googleapis.com`, que podría romper el video en Drive.
  - Rompe los portales cautivos de hoteles y aeropuertos.

## Network Extension (lo que usan Freedom u Opal)

Descartado por pesado:

- Requiere una extensión de sistema dentro de una app en `/Applications`.
- Requiere el entitlement de Network Extension, que solo da la **cuenta de desarrollador de pago** (US$99/año), más firma Developer ID y notarización.
- El usuario tiene que aprobarla en Ajustes, y depurarla exige desactivar SIP.
- `NEURLFilterManager` (macOS 26) es más simple, pero necesita un servidor propio (Bloom filter + PIR).
