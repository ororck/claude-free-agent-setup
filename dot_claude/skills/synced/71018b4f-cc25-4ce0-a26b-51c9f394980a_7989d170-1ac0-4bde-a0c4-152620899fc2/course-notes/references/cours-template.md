# Template HTML — Mode 2 : Cours complet (multi-pages)

## Règle fondamentale sur la pagination

**Ne jamais utiliser `page-break-before: always` entre les sections.**
Laisser wkhtmltopdf paginer naturellement. Les pages vides viennent de sauts forcés sur du contenu court.

Seules règles CSS de pagination à appliquer :
- `page-break-after: always` → uniquement sur `.cover` (après la page de garde)
- `page-break-inside: avoid` → sur `.svg-box`, `.def`, `.warn`, `table`, `.recap`
- `page-break-after: avoid` → sur les titres de section `.sh` (coller au contenu)

## Structure HTML

```html
<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<style>
* { margin:0; padding:0; box-sizing:border-box; }
body { font-family: Arial, sans-serif; font-size: 12px; color: #1a1a1a; line-height: 1.6; }

.cover { padding: 50px 0 30px; border-bottom: 4px solid {{COLOR}}; margin-bottom: 24px; page-break-after: always; }
.cover h1 { font-size: 34px; font-weight: 700; color: {{COLOR}}; margin-bottom: 6px; }
.cover .sub { font-size: 13px; color: #666; margin-bottom: 24px; }

.section { margin-bottom: 24px; }
.sh { display:flex; align-items:center; gap:10px; margin-bottom:12px; padding-bottom:7px; border-bottom:2px solid {{COLOR}}; page-break-after: avoid; }
.sn { background:{{COLOR}}; color:#fff; width:26px; height:26px; border-radius:50%; display:flex; align-items:center; justify-content:center; font-size:12px; font-weight:700; }
.sh h2 { font-size:17px; font-weight:700; color:{{COLOR}}; }

.svg-box { background:#f8fafc; border:1px solid #e2e8f0; border-radius:8px; padding:12px; margin-bottom:12px; text-align:center; page-break-inside: avoid; }
.svg-cap { font-size:10px; color:#94a3b8; margin-top:5px; font-style:italic; }

.def { background:{{COLOR}}0d; border-left:3px solid {{COLOR}}; padding:9px 13px; border-radius:0 6px 6px 0; margin:10px 0; page-break-inside: avoid; }
.def strong { display:block; font-size:10px; text-transform:uppercase; letter-spacing:.8px; color:{{COLOR}}; margin-bottom:3px; }

.warn { background:#fef3c7; border-left:3px solid #f59e0b; padding:7px 11px; border-radius:0 6px 6px 0; margin:9px 0; font-size:11px; page-break-inside: avoid; }
.warn::before { content:"⚠ Piège : "; font-weight:700; color:#92400e; }

table { width:100%; border-collapse:collapse; margin:10px 0; font-size:11px; page-break-inside: avoid; }
th { background:{{COLOR}}; color:#fff; padding:6px 9px; text-align:left; }
td { padding:5px 9px; border-bottom:1px solid #e5e7eb; }
tr:nth-child(even) td { background:#f9fafb; }

.recap { background:#f9fafb; border:1px solid #e5e7eb; border-radius:8px; padding:14px 18px; margin-bottom:12px; page-break-inside: avoid; }
.recap h3 { font-size:13px; font-weight:700; color:{{COLOR}}; margin-bottom:7px; }
.recap ul { list-style:none; }
.recap ul li { padding:2px 0 2px 15px; position:relative; }
.recap ul li::before { content:"✓"; position:absolute; left:0; color:{{COLOR}}; }
.recap ol { padding-left:17px; }
.recap ol li { margin-bottom:5px; }
p { margin-bottom:9px; color:#374151; }
strong { color:{{COLOR}}; }
</style>
</head>
<body>

<!-- Page de garde — seul page-break forcé -->
<div class="cover">
  <h1>{{TITRE}}</h1>
  <div class="sub">{{DOMAINE}} · {{NIVEAU}}</div>
  <!-- SVG plan d'ensemble ici -->
</div>

<!-- Sections — flux naturel, pas de page-break-before -->
<div class="section">
  <div class="sh"><div class="sn">1</div><h2>{{SECTION_TITRE}}</h2></div>
  <div class="svg-box">
    <!-- SVG du concept -->
  </div>
  <div class="def"><strong>Définition</strong>{{TEXTE}}</div>
  <p>{{TEXTE_COMPLEMENT}}</p>
  <div class="warn">{{PIEGE}}</div>
</div>

<!-- Répéter .section autant que nécessaire -->

<!-- Récap — en bas, flux naturel -->
<div class="recap"><h3>À retenir</h3><ul>...</ul></div>
<div class="recap"><h3>Questions de révision</h3><ol>...</ol></div>
</body>
</html>
```

## Couleurs par domaine
| Domaine | COLOR |
|---|---|
| Informatique / réseau | #2563eb |
| Maths / sciences | #7c3aed |
| Médecine / biologie | #059669 |
| Histoire / lettres | #92400e |
| Droit / éco | #1e40af |
