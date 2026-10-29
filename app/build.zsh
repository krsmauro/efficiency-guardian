#!/bin/zsh -f
# Compila la app de barra de menús (Fase 5) y arma app/build/EfficiencyGuardian.app.
# No instala nada ni necesita sudo. Antes de compilar ejecuta las pruebas de la
# lógica (swift test) y se niega a seguir si fallan.
#
# Uso: zsh app/build.zsh
# Después, para instalarla (lo hace el usuario; un administrador no necesita sudo):
#   cp -R app/build/EfficiencyGuardian.app /Applications/

emulate -R zsh
setopt ERR_EXIT NO_UNSET PIPE_FAIL
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

readonly HERE=${0:A:h}
readonly APP=$HERE/build/EfficiencyGuardian.app

print -r -- "== 1. Pruebas de la lógica (swift test)"
if ! swift test --package-path $HERE > $HERE/.build-tests.log 2>&1; then
  tail -n 30 $HERE/.build-tests.log
  print -r -- "Las pruebas fallan: no se compila la app. Detalle en $HERE/.build-tests.log"
  exit 1
fi
tail -n 1 $HERE/.build-tests.log
rm -f -- $HERE/.build-tests.log

print -r -- "== 2. Compilar (swift build -c release)"
swift build --package-path $HERE -c release --product GuardianBar
bin_dir=$(swift build --package-path $HERE -c release --show-bin-path)

print -r -- "== 3. Armar $APP"
rm -rf -- $APP
mkdir -p $APP/Contents/MacOS
cp $HERE/Info.plist $APP/Contents/Info.plist
cp $bin_dir/GuardianBar $APP/Contents/MacOS/EfficiencyGuardian

# Firma local ("ad-hoc", sin cuenta de Apple): macOS la exige para ejecutar
# en Apple Silicon. Cada compilación cambia la firma.
print -r -- "== 4. Firmar (local)"
codesign --force --sign - $APP
codesign --verify --strict $APP

print
print -r -- "Listo: $APP"
print -r -- "Para instalarla: cp -R ${APP#$PWD/} /Applications/"
