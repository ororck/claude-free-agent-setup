# Outils communs aux tests de delegate.sh et delegate-boN.sh. Charge par `load helpers`.

# depot <nom> : depot git minimal avec un commit, .worker-out ignore, une consigne. Cree aussi $T/<nom>-fake.
depot() {
  mkdir -p "$T/$1" "$T/$1-fake" "$T/tmp"
  git -C "$T/$1" init -q
  printf '.worker-out/\n' > "$T/$1/.gitignore"
  echo x > "$T/$1/README.md"
  echo consigne > "$T/$1/c.md"
  git -C "$T/$1" add -A
  git -C "$T/$1" -c user.name=t -c user.email=t@l commit -qm init
}

# contient <fichier> <contenu attendu> : vrai si le fichier a exactement ce contenu (sauf le dernier saut de ligne)
contient() { [ "$(cat "$1" 2>/dev/null)" = "${2%$'\n'}" ]; }
