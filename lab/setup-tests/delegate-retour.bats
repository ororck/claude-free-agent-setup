#!/usr/bin/env bats
# delegate.sh : retour arriere sur le meilleur essai, COPIER, SUFFIXE. Faux worker `opencode`, aucun appel LLM.

load helpers

DELEGATE="$HOME/.local/bin/delegate.sh"
VALIDE=$'#!/usr/bin/env bash\necho ok\n'
CASSE=$'#!/usr/bin/env bash\nif then\n'

# Faux worker : a l'essai N, copie dans le dossier courant les fichiers de $FAKE_DIR/essai-N/.
faux_opencode() {
  mkdir -p "$T/bin"
  cat > "$T/bin/opencode" <<'F'
#!/usr/bin/env bash
n=$(( $(cat "$FAKE_DIR/n" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$FAKE_DIR/n"
{ ls -A; cat .worker-out/*.erreurs.txt 2>/dev/null; } > "$FAKE_DIR/vu-$n"
cp -r "$FAKE_DIR/essai-$n/." .
F
  chmod +x "$T/bin/opencode"
}
essai() { # <nom> <n> <fichier> <contenu>
  mkdir -p "$T/$1-fake/essai-$2"; printf '%s' "$4" > "$T/$1-fake/essai-$2/$3"
}
lancer() { # <nom> <max essais> [VAR=valeur...] : ecrit le code de sortie dans $T/<nom>.code
  local nom="$1" n="$2" code=0; shift 2
  ( cd "$T/$nom" && env PATH="$T/bin:$PATH" FAKE_DIR="$T/$nom-fake" TMPDIR="$T/tmp" MAX_ESSAIS="$n" "$@" \
      "$DELEGATE" w c.md a.sh b.sh > sortie.txt 2>&1 ) || code=$?
  echo "$code" > "$T/$nom.code"
}

setup_file() {
  export T="$BATS_FILE_TMPDIR"
  faux_opencode

  # cas1 : essai 1 = a valide, b casse (1 echec). Essai 2 = a et b casses (2 echecs). Le recopie doit etre l'essai 1.
  depot cas1
  essai cas1 1 a.sh "$VALIDE"; essai cas1 1 b.sh "$CASSE"
  essai cas1 2 a.sh "$CASSE";  essai cas1 2 b.sh "$CASSE"
  lancer cas1 2

  # cas2 : essai 1 casse, essai 2 valide : reussite, recopie de l'essai 2.
  depot cas2
  essai cas2 1 a.sh "$CASSE";  essai cas2 1 b.sh "$CASSE"
  essai cas2 2 a.sh "$VALIDE"; essai cas2 2 b.sh "$VALIDE"
  lancer cas2 3

  # cas3 : scores egaux, pas d'annulation.
  depot cas3
  essai cas3 1 a.sh "$CASSE"; essai cas3 1 b.sh "$VALIDE"
  essai cas3 2 a.sh "$CASSE"; essai cas3 2 b.sh "$VALIDE"
  lancer cas3 2

  # cas4 : COPIER=0, lint OK.
  depot cas4
  essai cas4 1 a.sh "$VALIDE"; essai cas4 1 b.sh "$VALIDE"
  lancer cas4 1 COPIER=0

  # cas5 : COPIER=0, lint KO.
  depot cas5
  essai cas5 1 a.sh "$VALIDE"; essai cas5 1 b.sh "$CASSE"
  lancer cas5 1 COPIER=0

  # cas6 : SUFFIXE.
  depot cas6
  essai cas6 1 a.sh "$VALIDE"; essai cas6 1 b.sh "$VALIDE"
  lancer cas6 1 SUFFIXE=.w1

  # cas8 : 3 essais. Essai 1 = b casse. Essai 2 = pire, avec un fichier non suivi (extra.txt). L'essai 3 doit voir l'etat de l'essai 1 et ses erreurs.
  depot cas8
  essai cas8 1 a.sh "$VALIDE"; essai cas8 1 b.sh "$CASSE"
  essai cas8 2 a.sh "$CASSE";  essai cas8 2 b.sh "$CASSE"; essai cas8 2 extra.txt "pollution"
  mkdir -p "$T/cas8-fake/essai-3"
  lancer cas8 3
}

@test "retour arriere : sortie 2 quand l'essai 2 est pire et que rien ne passe" {
  [ "$(cat "$T/cas1.code")" -eq 2 ]
}

@test "retour arriere : a.sh recopie = celui de l'essai 1, pas du dernier" {
  contient "$T/cas1/a.sh" "$VALIDE"
}

@test "retour arriere : l'essai 2 annule est journalise" {
  grep -q 'ANNULE essai 2' "$T/cas1/.worker-out/delegate.log"
}

@test "reussite au 2e essai : sortie 0" {
  [ "$(cat "$T/cas2.code")" -eq 0 ]
}

@test "reussite au 2e essai : a.sh recopie" {
  contient "$T/cas2/a.sh" "$VALIDE"
}

@test "reussite au 2e essai : b.sh recopie" {
  [ -s "$T/cas2/b.sh" ]
}

@test "egalite de score : pas d'annulation" {
  run grep -c ANNULE "$T/cas3/.worker-out/delegate.log"
  [ "$output" -eq 0 ]
}

@test "COPIER=0, lint OK : sortie 0" {
  [ "$(cat "$T/cas4.code")" -eq 0 ]
}

@test "COPIER=0, lint OK : rien recopie dans le depot" {
  [ ! -e "$T/cas4/a.sh" ]
}

@test "COPIER=0, lint OK : worktree conserve, chemin en derniere ligne" {
  wt=$(tail -1 "$T/cas4/sortie.txt")
  [ -s "$wt/a.sh" ]
}

@test "COPIER=0, lint KO : sortie 2" {
  [ "$(cat "$T/cas5.code")" -eq 2 ]
}

@test "COPIER=0, lint KO : rien recopie" {
  [ ! -e "$T/cas5/a.sh" ]
}

@test "COPIER=0, lint KO : worktree supprime" {
  [ "$(git -C "$T/cas5" worktree list | wc -l)" -eq 1 ]
}

@test "SUFFIXE : sortie 0" {
  [ "$(cat "$T/cas6.code")" -eq 0 ]
}

@test "SUFFIXE : journal, run.log et diff suffixes" {
  [ -s "$T/cas6/.worker-out/delegate.w1.log" ]
  [ -e "$T/cas6/.worker-out/c.run.w1.log" ]
  [ -e "$T/cas6/.worker-out/c.w1.diff" ]
}

@test "SUFFIXE : aucun fichier ne garde son nom d'origine" {
  [ ! -e "$T/cas6/.worker-out/delegate.log" ]
  [ ! -e "$T/cas6/.worker-out/c.run.log" ]
}

@test "retour arriere : un fichier non suivi de l'essai annule ne survit pas" {
  run grep -c extra.txt "$T/cas8-fake/vu-3"
  [ "$output" -eq 0 ]
}

@test "retour arriere : l'essai suivant recoit les erreurs du meilleur essai (b.sh seul)" {
  grep -q 'b.sh :' "$T/cas8-fake/vu-3"
  run grep -c 'a.sh :' "$T/cas8-fake/vu-3"
  [ "$output" -eq 0 ]
}

@test "retour arriere : le fichier d'erreurs final decrit l'essai retenu" {
  grep -q 'b.sh :' "$T/cas8/.worker-out/c.erreurs.txt"
  run grep -c 'a.sh :' "$T/cas8/.worker-out/c.erreurs.txt"
  [ "$output" -eq 0 ]
}
