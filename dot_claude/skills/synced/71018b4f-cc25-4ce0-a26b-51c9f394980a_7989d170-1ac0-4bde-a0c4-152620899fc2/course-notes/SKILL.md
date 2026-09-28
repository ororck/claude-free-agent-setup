---
name: course-notes
description: >
  Synthèse de cours et prise de notes en deux modes distincts, toujours exportée en PDF visuel.
  MODE 1 — REMINDER : fiche mémo visuelle 1 page (schéma, couleurs, minimum de texte, max de rétention).
  MODE 2 — COURS COMPLET : PDF multi-pages avec un schéma SVG par concept + texte explicatif entre chaque.
  Déclenche ce skill dès que l'utilisateur dit : "fiche", "reminder", "schéma recap", "mémo", "fais-moi un cours",
  "cours complet", "explique-moi X en cours", "résumé de cours", "réviser", "notes de cours", "synthèse",
  ou colle du contenu brut (slides, transcription) à organiser. Toujours produire un fichier PDF téléchargeable.
  Utilise wkhtmltopdf pour la conversion HTML→PDF.
---

# Course Notes — Deux modes, toujours en PDF visuel

## Détection du mode

| Signal dans la demande | Mode |
|---|---|
| "fiche", "reminder", "mémo", "recap rapide", "aide-mémoire", "j'ai 5 min" | **Mode 1 — Reminder** |
| "cours complet", "explique-moi", "apprends-moi", "en détail", "cours sur X" | **Mode 2 — Cours complet** |
| Ambiguïté → demander : "Tu veux une fiche mémo rapide ou un cours complet ?" | — |

---

## Mode 1 — Reminder (fiche mémo 1 page)

**Objectif :** Une seule page A4, imprimable, scannable en 30 secondes. Priorité absolue à la rétention visuelle.

**Principes cognitifs appliqués :**
- Dual coding : chaque concept = texte + forme visuelle (SVG inline)
- Chunking : max 5-7 blocs distincts par page
- Hiérarchie visuelle : couleur + taille + position encodent l'importance

**Structure de la fiche :**
```
┌─────────────────────────────────────────┐
│  TITRE GRAND  │  Domaine · Niveau        │
├──────────┬──────────┬────────────────────┤
│ SVG      │ Concepts │ À retenir          │
│ central  │ clés     │ (3-5 bullets max)  │
│          ├──────────┤                    │
│          │ Liens /  ├────────────────────┤
│          │ relations│ Pièges courants    │
│          │          │ (2-3 max)          │
├──────────┴──────────┴────────────────────┤
│ Questions de révision flash (3 max)      │
└─────────────────────────────────────────┘
```

**Règles visuelles strictes :**
- Max 3 couleurs (une par groupe sémantique)
- Texte max 8 mots par bullet
- SVG central obligatoire (schéma du concept, cycle, hiérarchie, ou flow)
- Police : 11px normal, 14px titres
- Fond blanc, accent couleur sur les titres de section

**Génération :**
1. Rédiger le HTML complet (voir references/reminder-template.md)
2. Lancer scripts/build_pdf.sh avec le fichier HTML
3. Livrer le PDF avec present_files

---

## Mode 2 — Cours complet (PDF multi-pages)

**Objectif :** Un cours structuré et graphique. Chaque grand concept = schéma SVG + texte court. Jamais plus de 3 paragraphes consécutifs sans visuel.

**Structure du PDF :**
```
Page 1 : Titre + Objectifs + Prérequis + Mnémo + SVG plan (couverture dense)
─────────────────────────────────
Pages suivantes — pour chaque concept :
  [H2 Titre section]
  [SVG du concept — schéma illustratif ou structurel]
  [Définition + explication — max 150 mots]
  [Tableau ou liste si comparaison]
─────────────────────────────────
Dernière page : Récap + Questions de révision
```

**Types de SVG selon le contenu :**
| Contenu | Type |
|---|---|
| Process / étapes | Flowchart horizontal |
| Hiérarchie / couches | Structural (nested rects) |
| Mécanisme | Illustrative (formes libres) |
| Comparaison | Tableau visuel coloré |
| Cycle | Stepper ou cercle |
| Relations | Graphe de noeuds |

**Règles visuelles :**
- Un SVG par section (obligatoire)
- Palette 2-3 couleurs cohérentes sur tout le document
- Texte entre visuels : bref et direct
- Chaque SVG lisible sans le texte autour

**Génération :**
1. Découper le sujet en 4-8 sections logiques
2. Pour chaque section : écrire le SVG d'abord, puis le texte
3. Assembler le HTML complet (voir references/cours-template.md)
4. Convertir avec scripts/build_pdf.sh
5. Livrer avec present_files

---

## Contraintes techniques PDF

- Outil : wkhtmltopdf (toujours disponible, supporte SVG inline et CSS)
- Format : A4, marges 15mm
- SVG : toujours inline dans le HTML
- Fonts : Arial, Georgia, monospace (system fonts uniquement)
- Page break CSS : page-break-before: always

---

## Anti-patterns

- Ne jamais générer du texte en chat avant de livrer le PDF
- Pas de listes à puces sans structure visuelle en Mode 1
- Pas de plus de 3 paragraphes consécutifs en Mode 2
- SVG lisibles : pas trop chargés
- Toujours terminer avec present_files

## Références
- references/reminder-template.md — template HTML Mode 1
- references/cours-template.md — template HTML Mode 2
- scripts/build_pdf.sh — script de conversion

---

## Règle : passe finale d'allocation — OBLIGATOIRE avant de livrer

Après avoir écrit tout le HTML, **toujours faire cette vérification mentale page par page** avant de lancer wkhtmltopdf :

### Étape 1 — Estimer le remplissage de chaque page
Parcourir le HTML et estimer visuellement le % de remplissage de chaque page (couverture, pages intermédiaires, dernière page). Une page A4 avec marges 15mm = ~247mm de hauteur utile.

### Étape 2 — Redistribuer si nécessaire
| Situation | Action |
|---|---|
| Couverture < 80% remplie | Agrandir le SVG plan, augmenter padding, ajouter objectifs/prérequis/mnémo |
| Couverture a de la place ET sources prévues en fin | **Déplacer les sources sur la couverture**, pas en dernière page |
| Dernière page < 50% remplie | Déplacer les sources ici, ou agrandir les blocs récap/questions |
| Page intermédiaire < 60% remplie | Agrandir le SVG de la section (hauteur viewBox +30%), ou ajouter un tableau |
| Tout est bien rempli | Ne rien changer |

### Étape 3 — Ajuster les tailles si besoin
- SVG trop petit pour la place disponible → augmenter viewBox height
- Blocs trop compacts → augmenter padding, line-height
- Dernière section déborde d'une ligne sur une nouvelle page → réduire légèrement les SVG des sections précédentes

### Règle sources "Pour aller plus loin"
- Grille 3 colonnes, cartes typées (📄 Doc · ▶ Vidéo · 🛠 Outil · 📘 Livre), description ≤ 2 lignes
- **Placement prioritaire : couverture** (si espace disponible après objectifs/plan)
- Placement secondaire : dernière page (si espace après récap)
- Jamais au milieu du cours
