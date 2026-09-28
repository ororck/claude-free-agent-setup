#!/bin/bash
# Usage: build_pdf.sh <input.html> <output.pdf>
# Converts an HTML file (with inline SVG) to a PDF using wkhtmltopdf

INPUT="$1"
OUTPUT="$2"

if [ -z "$INPUT" ] || [ -z "$OUTPUT" ]; then
  echo "Usage: build_pdf.sh <input.html> <output.pdf>"
  exit 1
fi

wkhtmltopdf \
  --page-size A4 \
  --margin-top 15mm \
  --margin-bottom 15mm \
  --margin-left 15mm \
  --margin-right 15mm \
  --encoding utf-8 \
  --enable-local-file-access \
  --quiet \
  "$INPUT" "$OUTPUT"

echo "PDF généré : $OUTPUT"
