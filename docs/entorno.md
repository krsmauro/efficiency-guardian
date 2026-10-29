# Entorno de la máquina (hechos verificados)

> Hechos comprobados en la Mac del usuario. Si algo cambia (actualización de macOS, navegador nuevo), actualiza este archivo con la fecha.

Verificado el **2026-10-28**:

| Hecho | Valor | Cómo se verificó |
|---|---|---|
| Equipo | MacBook Pro, Apple Silicon (`arm64`) | `uname -m` |
| macOS | 27.0 (build 26A428) | `sw_vers` |
| Usuario es administrador | Sí (grupo `admin`) | `id -Gn` |
| `/etc/sudoers.d/` | Existe y está vacío | `ls -la /etc/sudoers.d` |
| Herramientas | Swift 6.4 + Xcode, Node 22 (vía nvm, en `~/.nvm`), Python 3.14 (Homebrew, en `/opt/homebrew`), `shortcuts` CLI en `/usr/bin/shortcuts` | `which`, `--version` |
| Atajos (Shortcuts) existentes | Ninguno (`shortcuts list` sale vacío) | `shortcuts list` |
| Navegadores instalados | Safari, Chrome, Brave, Vivaldi, Thorium (los 4 últimos son Chromium) | `ls /Applications` |
| Navegadores usados ese día | Brave, Vivaldi, Chrome y Thorium (Safari: último uso 2026-10-08) | `mdls -name kMDItemLastUsedDate` |
| DNS seguro (DoH) en Vivaldi y Thorium | Valor por defecto ("automático") | `Local State` de cada navegador |
| DNS seguro en Chrome y Brave | **No se pudo leer** (macOS bloquea el acceso a sus datos: `Operation not permitted`) | — |
| Red Wi‑Fi actual | Sin IPv6 global (solo IPv4) | `ifconfig` |
| Permisos de `/usr/local` | `root:wheel 755` (seguro para instalar un script root). `/usr/local/sbin` y `/usr/local/etc` **no existen**: los crea el instalador. `/var/db` es `root:wheel`. | `ls -ld` |
| Raycast | No instalado | `ls /Applications` |
| ID único por arranque | `sysctl -n kern.bootsessionuuid` existe y devuelve un UUID (cambia en cada arranque). Sirve para detectar apagado o reinicio en la Fase 4. | `sysctl` |
| Bundle IDs de navegadores | Safari `com.apple.Safari`, Chrome `com.google.Chrome`, Brave `com.brave.Browser`, Vivaldi `com.vivaldi.Vivaldi`, Thorium `org.chromium.Thorium` | `mdls` |
| AppleScript en navegadores Chromium | Los 4 (incluido Thorium) declaran `OSAScriptingDefinition = scripting.sdef`, así que tienen diccionario de scripting para la Fase 3 | `PlistBuddy` sobre `Info.plist` |
| Config. de modos de Concentración | **Protegida por macOS** (`~/Library/DoNotDisturb/DB/ModeConfigurations.json` → `Operation not permitted`). No sabemos qué modos tiene creados. Leer/vigilar ese archivo desde un script **no es viable** sin dar "Acceso total al disco". | `python3 open()` |

Verificado el **2026-10-29**:

| Hecho | Valor | Cómo se verificó |
|---|---|---|
| zsh | 5.9 en `/bin/zsh` | `zsh --version` |
| `log` en zsh | **Es un comando interno de zsh** (lista inicios de sesión): `log show …` falla con "too many arguments". Usar `/usr/bin/log show …`. | Probado en la terminal |
| `logger -t etiqueta` | La etiqueta **no** aparece en el texto del mensaje que filtra `log show`, así que `eventMessage CONTAINS "etiqueta"` no lo encuentra. El motor pone su nombre también dentro del mensaje. | `logger` + `/usr/bin/log show` |
| `visudo -c -f archivo` | Funciona sin root: sirve para validar en las pruebas la regla de sudoers generada | Probado |
| `/usr/local/libexec` | No existe: la crea el instalador | `ls -ld` |
| `/usr/local/lib` | `root:wheel 775` (escribible por el grupo `wheel`). No lo usamos; por eso los módulos van en `/usr/local/libexec`. | `ls -la /usr/local` |
| Candados para la Fase 4 | `/usr/bin/lockf` y `/usr/bin/shlock` existen. Al final se usó `zsystem flock` (abajo). | `ls -l` |
| **Apagados y arranques** | **El Mac se apaga casi todas las noches** y arranca cada mañana: 36 días de historial (del 23-09 al 29-10), el mayor tiempo encendido fue de unas 26 h. Algunos días falta el registro de apagado (apagado forzado o sin batería), pero el arranque sí está. Desmiente el supuesto S3 de la Fase 4. | `last \| grep -E '^(reboot\|shutdown)'` |
| Módulos de zsh | `zsh/datetime` (`EPOCHSECONDS`, `strftime`) y `zsh/system` (`zsystem flock`) están en `/usr/lib/zsh/5.9/zsh/`. `zsystem flock` exige que el archivo exista, espera con `-t segundos` (sale con 2 si se agota) y suelta el candado al terminar el proceso, también con `exit 1`. | Probado en la terminal |
| `install -d` sobre una carpeta que ya existe | **Sí** le cambia los permisos (`700` → `755`): así el instalador de la Fase 4 corrige la carpeta de datos de la Fase 1 | Probado con una carpeta temporal |
| `plutil` y JSON | `plutil -extract clave raw -o - archivo.json` lee JSON (y falla si es inválido). `plutil -lint` **no** acepta JSON. | Probado |

## Estado del bloqueo manual previo

El usuario ya bloqueó YouTube a mano en `/etc/hosts` (y luego tuvo que desbloquearlo para algo legítimo; ver [conversation.txt](../conversation.txt)). Contenido al 2026-10-28:

```
127.0.0.1	localhost
255.255.255.255	broadcasthost
::1             localhost
0.0.0.0 youtube.com
0.0.0.0 www.youtube.com
0.0.0.0 m.youtube.com
0.0.0.0 youtu.be
```

### Huecos encontrados en ese bloqueo (probados)

1. **Fuga por IPv6.** `dscacheutil -q host -a name youtube.com` devuelve `0.0.0.0` **y además** la IPv6 real de YouTube (`2800:3f0:4005:401::200e`). En esta Wi‑Fi no importa porque no hay IPv6, pero en una red con IPv6 (hotspot del celular, oficina) YouTube cargaría. → Cada dominio bloqueado necesita también una línea IPv6 (`:: dominio`).
2. **Subdominios sin bloquear.** `music.youtube.com`, `i.ytimg.com` y `youtube-nocookie.com` resuelven a IPs reales. `/etc/hosts` no admite comodines: hay que listar cada subdominio.
3. **Líneas sueltas, sin marcador.** No hay forma segura de quitarlas/ponerlas por script sin riesgo de tocar otras líneas. → El motor debe escribir dentro de un bloque delimitado por marcadores.

> Nota: estas líneas manuales deben migrarse al bloque gestionado (o borrarse) cuando se instale el motor, para que "apagar" de verdad desbloquee YouTube.
