#!/usr/bin/env bats
# boN + vrai delegate.sh + faux opencode : les fichiers d'erreurs ecrits par delegate.sh (SUFFIXE) sont bien
# ceux que le boN relit, donc la passe de raffinement se declenche sur le worker au fichier d'erreurs le plus court.

load helpers

BON="$HOME/.local/bin/delegate-boN.sh"

# Faux opencode : la consigne de raffinement (elle porte les erreurs) recoit un fichier valide ; sinon un fichier
# python casse dont le nombre de noms indefinis depend du modele (w1 : 3, w2 : 1, w3 : 2).
faux_opencode() {
  mkdir -p "$T/bin"
  cat > "$T/bin/opencode" <<'F'
#!/usr/bin/env bash
modele=""; consigne=""
while [ $# -gt 0 ]; do
  case "$1" in -m) modele="$2"; shift ;; --file) case "$2" in *.consigne.md) consigne="$2" ;; esac; shift ;; esac
  shift
done
echo "$modele" >> "$FAKE_DIR/modeles"
if grep -q 'Erreurs de la tentative precedente' "$consigne"; then echo "x = 1" > out.py; exit 0; fi
case "$modele" in
  *w1) printf 'a1\na2\na3\n' ;;
  *w2) printf 'a1\n' ;;
  *w3) printf 'a1\na2\n' ;;
esac > out.py
F
  chmod +x "$T/bin/opencode"
}

setup_file() {
  export T="$BATS_FILE_TMPDIR"
  faux_opencode
  depot cas1
  code=0
  ( cd "$T/cas1" && env PATH="$T/bin:$HOME/.local/bin:$PATH" FAKE_DIR="$T/cas1-fake" TMPDIR="$T/tmp" \
      "$BON" "w1,w2,w3" c.md out.py > sortie.txt 2>&1 ) || code=$?
  echo "$code" > "$T/cas1.code"
}

@test "tous les workers echouent au lint : chacun laisse son fichier d'erreurs sous le nom relu par le boN" {
  for w in w1 w2 w3; do [ -s "$T/cas1/.worker-out/c.erreurs.$w.txt" ]; done
}

@test "tous les workers echouent au lint : le raffinement se declenche sur le fichier d'erreurs le plus court (w2)" {
  grep -q 'RAFFINEMENT sur w2 ' "$T/cas1/.worker-out/delegate.log"
  run grep -c 'aucun worker n' "$T/cas1/.worker-out/delegate.log"
  [ "$output" -eq 0 ]
}

@test "tous les workers echouent au lint : la passe de raffinement reussit et recopie le livrable" {
  [ "$(cat "$T/cas1.code")" -eq 0 ]
  contient "$T/cas1/out.py" "x = 1"
}
