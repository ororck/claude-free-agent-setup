#!/usr/bin/env bats
# delegate-boN.sh : best-of-N. Faux delegate.sh place en tete de PATH, aucun appel LLM.

load helpers

BON="$HOME/.local/bin/delegate-boN.sh"

# Faux delegate.sh, pilote par $FAKE_DIR/plan.<worker> : "ok <delai>" ou "ko <lignes d'erreurs> <delai>".
# Une passe de raffinement (COPIER=1) lit $FAKE_DIR/refine.<worker> : "<code de sortie>".
faux_delegate() {
  mkdir -p "$T/bin"
  cat > "$T/bin/delegate.sh" <<'F'
#!/usr/bin/env bash
w="$1"; consigne="$2"; shift 2
tache="$(basename "$consigne" .md)"
echo "$w COPIER=${COPIER:-1} MAX_ESSAIS=${MAX_ESSAIS:-} SUFFIXE=${SUFFIXE:-} consigne=$consigne" >> "$FAKE_DIR/calls"
echo "+ $w" >> "$FAKE_DIR/events"
trap 'echo "- $w" >> "$FAKE_DIR/events"; exit 143' TERM
fin() { echo "- $w" >> "$FAKE_DIR/events"; }
if [ "${COPIER:-1}" = 1 ]; then
  cp "$consigne" "$FAKE_DIR/consigne-raffinee.$w"
  code=$(cat "$FAKE_DIR/refine.$w" 2>/dev/null || echo 0)
  for f in "$@"; do echo "raffine-$w" > "$f"; done
  fin; exit "$code"
fi
read -r verdict n delai < "$FAKE_DIR/plan.$w"
if [ "$verdict" = ok ]; then delai=$n; fi
sleep "$delai" & echo $! >> "$FAKE_DIR/enfants"; wait $!
if [ "$verdict" = ok ]; then
  wt="$TMPDIR/delegate-wt/$(basename "$PWD")-$tache-$$"; mkdir -p "$wt"
  for f in "$@"; do mkdir -p "$wt/$(dirname "$f")"; echo "de-$w" > "$wt/$f"; done
  echo "OK $tache"; echo "$wt"; fin; exit 0
fi
mkdir -p .worker-out
for i in $(seq 1 "$n"); do echo "erreur $i de $w"; done > ".worker-out/$tache.erreurs$SUFFIXE.txt"
echo "ECHEC $tache"; fin; exit 2
F
  chmod +x "$T/bin/delegate.sh"
}
plan() { echo "$3" > "$T/$1-fake/plan.$2"; } # <cas> <worker> <ligne>
lancer() { # <cas> "<workers>" [VAR=valeur...] : ecrit code et duree dans $T/<cas>.code / .duree
  local nom="$1" workers="$2" code=0 debut=$SECONDS; shift 2
  ( cd "$T/$nom" && env PATH="$T/bin:$PATH" FAKE_DIR="$T/$nom-fake" TMPDIR="$T/tmp" "$@" \
      "$BON" "$workers" c.md out.txt > sortie.txt 2>&1 ) || code=$?
  echo "$code" > "$T/$nom.code"; echo $((SECONDS - debut)) > "$T/$nom.duree"
}
nb() { grep -c "$1" "$2" || true; } # <motif> <fichier>
max_simultanes() { awk '/^\+/{n++; if(n>m)m=n} /^-/{n--} END{print m+0}' "$T/$1-fake/events"; }

setup_file() {
  export T="$BATS_FILE_TMPDIR"
  faux_delegate

  # cas1 : un seul worker reussit (w2). w1 echoue vite, w3 dormirait 30 s : il doit etre tue.
  depot cas1
  plan cas1 w1 "ko 5 0.2"; plan cas1 w2 "ok 0.6"; plan cas1 w3 "ko 5 30"
  lancer cas1 "w1,w2,w3"

  # cas2 : aucun ne reussit. w2 a le moins de lignes d'erreurs : raffinement sur w2 seul, son code est propage.
  depot cas2
  plan cas2 w1 "ko 7 0.2"; plan cas2 w2 "ko 3 0.3"; plan cas2 w3 "ko 5 0.4"; echo 7 > "$T/cas2-fake/refine.w2"
  lancer cas2 "w1,w2,w3"

  # cas3 : plafond MAX_PAR. 5 workers, aucun ne reussit.
  depot cas3
  for w in w1 w2 w3 w4 w5; do plan cas3 "$w" "ko 4 0.6"; done
  lancer cas3 "w1,w2,w3,w4,w5" MAX_PAR=3
}

@test "un seul worker reussit : sortie 0" {
  [ "$(cat "$T/cas1.code")" -eq 0 ]
}

@test "un seul worker reussit : livrable du gagnant recopie" {
  contient "$T/cas1/out.txt" "de-w2"
}

@test "un seul worker reussit : recopie une seule fois, journalisee avec le gagnant" {
  [ "$(nb 'OK gagnant w2' "$T/cas1/.worker-out/delegate.log")" -eq 1 ]
}

@test "un seul worker reussit : aucune passe de raffinement" {
  [ "$(nb 'COPIER=1' "$T/cas1-fake/calls")" -eq 0 ]
}

@test "un seul worker reussit : les workers tournent avec COPIER=0 MAX_ESSAIS=1 et un suffixe" {
  [ "$(nb 'COPIER=0 MAX_ESSAIS=1 SUFFIXE=\.w' "$T/cas1-fake/calls")" -eq 3 ]
}

@test "un seul worker reussit : le worker lent est tue sans attendre 30 s" {
  [ "$(cat "$T/cas1.duree")" -lt 15 ]
}

@test "un seul worker reussit : worktrees nettoyes" {
  [ -z "$(ls -A "$T/tmp/delegate-wt" 2>/dev/null)" ]
}

@test "aucun ne reussit : code de la passe de raffinement propage" {
  [ "$(cat "$T/cas2.code")" -eq 7 ]
}

@test "aucun ne reussit : une seule passe, sur le moins mauvais (w2), COPIER=1 MAX_ESSAIS=1" {
  [ "$(grep 'COPIER=1' "$T/cas2-fake/calls" | grep -c '^w2 COPIER=1 MAX_ESSAIS=1')" -eq 1 ]
  [ "$(nb 'COPIER=1' "$T/cas2-fake/calls")" -eq 1 ]
}

@test "aucun ne reussit : la consigne de raffinement porte les erreurs de w2 et pas celles des autres" {
  grep -q 'erreur 3 de w2' "$T/cas2-fake/consigne-raffinee.w2"
  [ "$(nb 'de w1' "$T/cas2-fake/consigne-raffinee.w2")" -eq 0 ]
}

@test "aucun ne reussit : raffinement journalise" {
  grep -q 'RAFFINEMENT sur w2' "$T/cas2/.worker-out/delegate.log"
}

@test "MAX_PAR : les 5 workers ont tourne" {
  [ "$(nb 'COPIER=0' "$T/cas3-fake/calls")" -eq 5 ]
}

@test "MAX_PAR : jamais plus de 3 processus simultanes" {
  [ "$(max_simultanes cas3)" -le 3 ]
}

@test "MAX_PAR : le plafond est atteint (le test n'est pas vide)" {
  [ "$(max_simultanes cas3)" -eq 3 ]
}

@test "un seul worker reussit : aucun processus enfant orphelin (groupe tue, pas le seul PID)" {
  [ -s "$T/cas1-fake/enfants" ]
  while read -r pid; do
    ! kill -0 "$pid" 2>/dev/null
  done < "$T/cas1-fake/enfants"
}
