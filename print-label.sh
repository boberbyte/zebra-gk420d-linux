#!/bin/bash
# zebra-gk420d-linux: print-label.sh
# Converts an HTML label file to PDF and prints it on the Zebra GK420d.
# Useful when browser print margins cause misalignment.
#
# Usage: ./print-label.sh label.html
# Requires: wkhtmltopdf, ghostscript

PRINTER="${ZEBRA_PRINTER:-Zebra_Technologies_ZTC_GK420d}"
LABEL_W="${LABEL_W:-105}"
LABEL_H="${LABEL_H:-220}"
CSS_FILE="$(dirname "$0")/zebra-print.css"

HTML="$1"

if [ -z "$HTML" ] || [ ! -f "$HTML" ]; then
    echo "Usage: $0 <label.html>"
    exit 1
fi

DIR=$(dirname "$HTML")
PDF_FULL="/tmp/zebra-full.pdf"
PDF_P1="/tmp/zebra-p1.pdf"

echo "Converting $HTML → PDF..."
wkhtmltopdf \
    --page-width "${LABEL_W}mm" \
    --page-height "${LABEL_H}mm" \
    --margin-top 0mm \
    --margin-bottom 0mm \
    --margin-left 2mm \
    --margin-right 2mm \
    --allow "$DIR" \
    --zoom 0.75 \
    --dpi 96 \
    --user-style-sheet "$CSS_FILE" \
    "$HTML" "$PDF_FULL" 2>/dev/null

echo "Extracting page 1..."
gs -dBATCH -dNOPAUSE -dQUIET -sDEVICE=pdfwrite \
    -dFirstPage=1 -dLastPage=1 \
    -sOutputFile="$PDF_P1" "$PDF_FULL"

echo "Sending to $PRINTER..."
lp -d "$PRINTER" \
    -o "PageSize=w298h624" \
    "$PDF_P1"

echo "Done!"
