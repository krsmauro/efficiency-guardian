#!/bin/zsh -f
# Regla de tamaño (D13): cada archivo de código tiene una sola responsabilidad y
# unas 100 líneas como máximo, para poder depurarlo leyéndolo de principio a fin.
#   - Más de 100 líneas: AVISO. Divídelo antes de seguir añadiendo.
#   - 150 líneas o más: ERROR. Las pruebas fallan y el instalador no instala.
# Las líneas se cuentan con wc -l, incluidos comentarios y líneas en blanco.
#
# Cuenta como código: bin/, lib/, close-tabs/, install*, uninstall*, tools/, tests/ y app/
# (Swift y zsh). No cuentan los datos (blocklists/, tests/fixtures/, los .json y
# .plist de app/) ni la documentación (.md).
#
# Uso: check-length.zsh [carpeta del repositorio]   (por defecto, la de este archivo)

emulate -R zsh
setopt NO_UNSET PIPE_FAIL EXTENDED_GLOB
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

readonly WARN_ABOVE=100
readonly FAIL_FROM=150

cd -- ${1:-${0:A:h:h}}

files=(
  bin/*(N.)
  lib/**/*(N.)
  close-tabs/**/*(N.)
  install*(N.)
  install/**/*(N.)
  uninstall*(N.)
  tools/**/*(N.)
  tests/**/*~tests/fixtures/*(N.)
  app/**/*.swift(N.)
  app/*.zsh(N.)
)
files=(${files:#*.md})

failed=0
for file in $files; do
  lines=$(( $(wc -l < $file) ))
  if (( lines >= FAIL_FROM )); then
    print -r -- "  ERROR  $file: $lines líneas ($FAIL_FROM o más es inaceptable; divídelo)"
    failed=1
  elif (( lines > WARN_ABOVE )); then
    print -r -- "  AVISO  $file: $lines líneas (máximo recomendado: $WARN_ABOVE; divídelo pronto)"
  fi
done

print -r -- "  $#files archivos de código revisados"
exit $failed
