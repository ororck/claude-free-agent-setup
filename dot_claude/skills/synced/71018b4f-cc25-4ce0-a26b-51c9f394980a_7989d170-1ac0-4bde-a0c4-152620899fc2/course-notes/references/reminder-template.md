# Template HTML — Mode 1 : Reminder (fiche mémo 1 page)

Utilise ce template comme base. Remplace les placeholders `{{...}}` par le contenu réel.
Le SVG est généré inline selon le contenu (flowchart, hiérarchie, cycle, etc.).

```html
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: Arial, sans-serif;
    font-size: 11px;
    color: #1a1a1a;
    background: #fff;
    width: 100%;
  }

  /* ── En-tête ── */
  .header {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    border-bottom: 3px solid {{COLOR_PRIMARY}};
    padding-bottom: 6px;
    margin-bottom: 10px;
  }
  .header h1 {
    font-size: 22px;
    font-weight: 700;
    color: {{COLOR_PRIMARY}};
    letter-spacing: -0.5px;
  }
  .header .meta {
    font-size: 10px;
    color: #888;
    text-align: right;
  }

  /* ── Grille principale ── */
  .grid {
    display: grid;
    grid-template-columns: 220px 1fr 1fr;
    grid-template-rows: auto auto;
    gap: 10px;
    margin-bottom: 10px;
  }

  /* ── Bloc SVG central ── */
  .svg-block {
    grid-row: 1 / 3;
    background: #f8f8f8;
    border: 1px solid #e0e0e0;
    border-radius: 6px;
    padding: 8px;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  /* ── Blocs texte ── */
  .block {
    background: #fff;
    border: 1px solid #e0e0e0;
    border-radius: 6px;
    padding: 8px 10px;
  }
  .block h2 {
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.8px;
    color: {{COLOR_PRIMARY}};
    border-bottom: 1px solid {{COLOR_PRIMARY}}33;
    padding-bottom: 4px;
    margin-bottom: 6px;
  }
  .block ul {
    list-style: none;
    padding: 0;
  }
  .block ul li {
    padding: 2px 0 2px 12px;
    position: relative;
    line-height: 1.4;
  }
  .block ul li::before {
    content: "▸";
    position: absolute;
    left: 0;
    color: {{COLOR_PRIMARY}};
    font-size: 9px;
    top: 3px;
  }

  /* ── Bloc piège (accent couleur 2) ── */
  .block.danger h2 { color: {{COLOR_DANGER}}; border-color: {{COLOR_DANGER}}33; }
  .block.danger ul li::before { color: {{COLOR_DANGER}}; }

  /* ── Bande questions ── */
  .questions {
    background: {{COLOR_PRIMARY}}0d;
    border: 1px solid {{COLOR_PRIMARY}}33;
    border-radius: 6px;
    padding: 8px 12px;
  }
  .questions h2 {
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.8px;
    color: {{COLOR_PRIMARY}};
    margin-bottom: 6px;
  }
  .questions ol {
    padding-left: 16px;
    display: grid;
    grid-template-columns: 1fr 1fr 1fr;
    gap: 4px 16px;
  }
  .questions ol li {
    line-height: 1.4;
    color: #333;
  }

  /* ── Pied de page ── */
  .footer {
    margin-top: 6px;
    font-size: 9px;
    color: #bbb;
    text-align: right;
  }
</style>
</head>
<body>

<!-- EN-TÊTE -->
<div class="header">
  <h1>{{TITRE}}</h1>
  <div class="meta">{{DOMAINE}} &nbsp;·&nbsp; {{NIVEAU}}</div>
</div>

<!-- GRILLE PRINCIPALE -->
<div class="grid">

  <!-- SVG central — REMPLACER par le SVG approprié au sujet -->
  <div class="svg-block">
    <svg width="200" height="240" viewBox="0 0 200 240" xmlns="http://www.w3.org/2000/svg">
      <!-- INSÉRER LE SVG DU CONCEPT ICI -->
      <!-- Ex: flowchart, couches, cycle, graphe de relations -->
    </svg>
  </div>

  <!-- Concepts clés -->
  <div class="block">
    <h2>Concepts clés</h2>
    <ul>
      <li>{{CONCEPT_1}}</li>
      <li>{{CONCEPT_2}}</li>
      <li>{{CONCEPT_3}}</li>
      <li>{{CONCEPT_4}}</li>
      <li>{{CONCEPT_5}}</li>
    </ul>
  </div>

  <!-- À retenir -->
  <div class="block">
    <h2>À retenir</h2>
    <ul>
      <li>{{RETENIR_1}}</li>
      <li>{{RETENIR_2}}</li>
      <li>{{RETENIR_3}}</li>
    </ul>
  </div>

  <!-- Relations / liens -->
  <div class="block">
    <h2>Relations</h2>
    <ul>
      <li>{{LIEN_1}}</li>
      <li>{{LIEN_2}}</li>
      <li>{{LIEN_3}}</li>
    </ul>
  </div>

  <!-- Pièges courants -->
  <div class="block danger">
    <h2>⚠ Pièges courants</h2>
    <ul>
      <li>{{PIEGE_1}}</li>
      <li>{{PIEGE_2}}</li>
    </ul>
  </div>

</div>

<!-- QUESTIONS FLASH -->
<div class="questions">
  <h2>Questions de révision</h2>
  <ol>
    <li>{{QUESTION_1}}</li>
    <li>{{QUESTION_2}}</li>
    <li>{{QUESTION_3}}</li>
  </ol>
</div>

<div class="footer">Généré par Claude · course-notes skill</div>
</body>
</html>
```

## Variables de couleur à choisir selon le domaine

| Domaine | COLOR_PRIMARY | COLOR_DANGER |
|---|---|---|
| Informatique / réseau | #2563eb | #dc2626 |
| Maths / sciences | #7c3aed | #ea580c |
| Médecine / biologie | #059669 | #dc2626 |
| Histoire / lettres | #92400e | #b91c1c |
| Droit / éco | #1e40af | #9f1239 |
| Générique | #374151 | #b45309 |
