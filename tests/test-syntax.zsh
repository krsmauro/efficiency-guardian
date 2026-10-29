#!/bin/zsh -f
# Comprueba la sintaxis (zsh -n) de todos los archivos de código. Importa sobre
# todo para install.sh y uninstall.sh, que las pruebas no pueden ejecutar porque
# necesitan root: así un error de escritura no aparece por primera vez con sudo.
# El JavaScript de close-tabs se compila con osacompile, sin ejecutarlo.

source ${0:A:h}/assert.zsh

section "Sintaxis"
for file in $REPO/bin/guardian $REPO/lib/*.zsh $REPO/install.sh $REPO/uninstall.sh \
            $REPO/install/*.zsh $REPO/close-tabs/*.zsh $REPO/tools/*.zsh(N) $REPO/tests/*.zsh; do
  assert_true "${file#$REPO/}" zsh -n $file
done
for file in $REPO/close-tabs/*.js $REPO/tests/*.js; do
  assert_true "${file#$REPO/} (JavaScript)" osacompile -l JavaScript -o $T_TMP/syntax.scpt $file
done

section "Primera línea de los ejecutables"
for file in $REPO/bin/guardian $REPO/install.sh $REPO/uninstall.sh $REPO/close-tabs/close-tabs.zsh; do
  # "-f": zsh no lee los archivos de arranque del usuario (ver bin/guardian).
  assert_eq "${file#$REPO/} usa /bin/zsh -f" '#!/bin/zsh -f' "$(head -n 1 $file)"
  assert_true "${file#$REPO/} es ejecutable" test -x $file
done

finish
