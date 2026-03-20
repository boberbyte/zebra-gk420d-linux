#!/bin/bash
# zebra-gk420d-linux: calibrate.sh
# Interactive ZPL calibration helper — find correct dots for your label size

PRINTER="${1:-Zebra_Technologies_ZTC_GK420d}"

send_zpl() {
    printf "$1" | lp -d "$PRINTER" -o raw -
}

echo "=== Zebra ZPL Calibration Helper ==="
echo "Printer: $PRINTER"
echo ""

# Step 1: DPI test
echo "STEP 1: Confirm DPI"
echo "Printing two boxes — measure which is 10mm wide."
echo "  Box A = 80 dots  (10mm @ 203dpi)"
echo "  Box B = 118 dots (10mm @ 300dpi)"
read -rp "Press Enter to print..."
send_zpl "^XA\n^PW400\n^LL400\n^FO10,10^GB80,80,3^FS\n^FO10,100^A0N,25,25^FD10mm@203dpi^FS\n^FO10,150^GB118,118,3^FS\n^FO10,280^A0N,25,25^FD10mm@300dpi^FS\n^XZ"

read -rp "Which box is 10mm? (203/300): " DPI
DPI="${DPI:-203}"
DOTS_PER_MM=$(echo "scale=4; $DPI / 25.4" | bc)
echo "Using $DPI dpi ($DOTS_PER_MM dots/mm)"
echo ""

# Step 2: Label dimensions
echo "STEP 2: Enter label dimensions"
read -rp "Label width  (mm): " W_MM
read -rp "Label height (mm): " H_MM
W=$(echo "$W_MM * $DOTS_PER_MM / 1" | bc)
H=$(echo "$H_MM * $DOTS_PER_MM / 1" | bc)
echo "Calculated: ${W} x ${H} dots"
echo ""

# Step 3: Find actual printable height
echo "STEP 3: Find actual printable height"
echo "Printing full-size frame. Check if all 4 corners are visible."
echo "If bottom is cut off, reduce LL. Adjust until all 4 corners show."

LL=$H
while true; do
    read -rp "Test with LL=$LL? (Enter=yes, or type new value): " INPUT
    [ -n "$INPUT" ] && LL=$INPUT
    send_zpl "^XA\n^PW${W}\n^LL${LL}\n^FO5,5^GB$((W-10)),$((LL-10)),4^FS\n^FO20,$((LL/2))^A0N,30,30^FDAll 4 corners?^FS\n^XZ"
    read -rp "All 4 corners visible? (y/n): " OK
    [ "$OK" = "y" ] && break
done
echo "Confirmed LL=$LL"
echo ""

# Step 4: Vertical alignment
echo "STEP 4: Vertical alignment (LT)"
echo "Adjust LT until content is centered on label. Negative = up."
LT=-24
while true; do
    read -rp "Test with LT=$LT? (Enter=yes, or type new value): " INPUT
    [ -n "$INPUT" ] && LT=$INPUT
    send_zpl "^XA\n^LT${LT}\n^PW${W}\n^LL${LL}\n^FO5,5^GB$((W-10)),$((LL-10)),4^FS\n^FO20,$((LL/2))^A0N,30,30^FDCentered?^FS\n^XZ"
    read -rp "Centered? (y/n): " OK
    [ "$OK" = "y" ] && break
done
echo "Confirmed LT=$LT"
echo ""

# Step 5: Save to NVRAM
echo "STEP 5: Save to printer NVRAM"
read -rp "Save these settings permanently? (y/n): " SAVE
if [ "$SAVE" = "y" ]; then
    send_zpl "^XA\n^LH0,0\n^LT${LT}\n^PW${W}\n^LL${LL}\n^JUS\n^XZ"
    echo "Saved: PW=$W LL=$LL LT=$LT"
fi

echo ""
echo "=== Calibration complete! ==="
echo "PW=$W  LL=$LL  LT=$LT  DPI=$DPI"
