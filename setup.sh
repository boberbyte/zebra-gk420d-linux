#!/bin/bash
# zebra-gk420d-linux: setup.sh
# Configures Zebra GK420d (203dpi) for custom label sizes on Linux/CUPS

set -e

PRINTER_NAME="${1:-Zebra_Technologies_ZTC_GK420d}"
PPD="/etc/cups/ppd/${PRINTER_NAME}.ppd"

echo "=== Zebra GK420d Linux Setup ==="
echo ""

# --- Input ---
read -rp "Label width  (mm): " WIDTH_MM
read -rp "Label height (mm): " HEIGHT_MM
read -rp "Printer DPI [203]: " DPI
DPI="${DPI:-203}"

# --- Calculate dots ---
DOTS_PER_MM=$(echo "scale=4; $DPI / 25.4" | bc)
WIDTH_DOTS=$(echo "$WIDTH_MM * $DOTS_PER_MM / 1" | bc)
HEIGHT_DOTS=$(echo "$HEIGHT_MM * $DOTS_PER_MM / 1" | bc)

# Points (72pt/inch) for PPD
WIDTH_PT=$(echo "scale=0; $WIDTH_MM / 25.4 * 72 / 1" | bc)
HEIGHT_PT=$(echo "scale=0; $HEIGHT_MM / 25.4 * 72 / 1" | bc)

SIZE_NAME="w${WIDTH_PT}h${HEIGHT_PT}"
LABEL_NAME="${WIDTH_MM}x${HEIGHT_MM}mm"

echo ""
echo "Label size name : $LABEL_NAME"
echo "PPD size key    : $SIZE_NAME"
echo "Width  in dots  : $WIDTH_DOTS"
echo "Height in dots  : $HEIGHT_DOTS"
echo "Width  in pt    : $WIDTH_PT"
echo "Height in pt    : $HEIGHT_PT"
echo ""

# --- Backup PPD ---
if [ ! -f "${PPD}.bak" ]; then
    sudo cp "$PPD" "${PPD}.bak"
    echo "Backed up PPD to ${PPD}.bak"
fi

# --- Add paper size to PPD ---
sudo python3 - <<PYEOF
import re

ppd = open("$PPD").read()

entries = {
    "PageSize":       f'*PageSize $SIZE_NAME/$LABEL_NAME: "<</PageSize[$WIDTH_PT $HEIGHT_PT]/ImagingBBox null>>setpagedevice"',
    "PageRegion":     f'*PageRegion $SIZE_NAME/$LABEL_NAME: "<</PageSize[$WIDTH_PT $HEIGHT_PT]/ImagingBBox null>>setpagedevice"',
    "ImageableArea":  f'*ImageableArea $SIZE_NAME/$LABEL_NAME: "0 0 $WIDTH_PT $HEIGHT_PT"',
    "PaperDimension": f'*PaperDimension $SIZE_NAME/$LABEL_NAME: "$WIDTH_PT $HEIGHT_PT"',
}

for key, line in entries.items():
    pattern = rf'^\*{key} $SIZE_NAME/'
    if not re.search(pattern, ppd, re.MULTILINE):
        ppd = re.sub(
            rf'(\*{key} \S+/[^:]+:.*)',
            rf'\1\n{line}',
            ppd, count=1
        )

# Update MaxMediaWidth
ppd = re.sub(r'\*MaxMediaWidth: "\d+"', f'*MaxMediaWidth: "$WIDTH_PT"', ppd)

# Set as default
ppd = re.sub(r'\*DefaultPageSize: \S+', f'*DefaultPageSize: $SIZE_NAME', ppd)
ppd = re.sub(r'\*DefaultPageRegion: \S+', f'*DefaultPageRegion: $SIZE_NAME', ppd)
ppd = re.sub(r'\*DefaultImageableArea: \S+', f'*DefaultImageableArea: $SIZE_NAME', ppd)

open("$PPD", "w").write(ppd)
print("PPD updated.")
PYEOF

# --- Set zeLabelTop default ---
read -rp "Set DefaultzeLabelTop [35]: " LABELTOP
LABELTOP="${LABELTOP:-35}"
sudo sed -i "s/\*DefaultzeLabelTop: .*/*DefaultzeLabelTop: $LABELTOP/" "$PPD"

# --- Restart CUPS ---
sudo systemctl restart cups
echo "CUPS restarted."

# --- Set lpoptions ---
lpoptions -p "$PRINTER_NAME" -o "PageSize=${SIZE_NAME}"
echo "Default paper size set to $LABEL_NAME."

# --- Save ZPL calibration to printer NVRAM ---
echo ""
echo "Saving ZPL calibration to printer NVRAM..."
printf "^XA\n^LH0,0\n^LT-24\n^PW${WIDTH_DOTS}\n^LL${HEIGHT_DOTS}\n^JUS\n^XZ" \
  | lp -d "$PRINTER_NAME" -o raw -

echo ""
echo "=== Setup complete! ==="
echo "Print with: Firefox -> $LABEL_NAME -> Margins: None"
