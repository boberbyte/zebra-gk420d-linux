# zebra-gk420d-linux

A practical guide and scripts for getting the **Zebra GK420d** label printer working properly on Linux (Ubuntu/Linux Mint) with CUPS — including custom label sizes, correct DPI calibration, and ZPL alignment.

## The Problem

The Zebra GK420d works on Linux via CUPS with the bundled PPD driver, but out of the box you'll run into several issues:

- **Wrong DPI assumption**: The PPD declares 300dpi as default, but the GK420d hardware runs at **203dpi**. This causes all ZPL dot calculations to be off.
- **No custom label sizes**: The PPD only includes pre-defined inch-based sizes. If you use metric labels (e.g. 105×220mm), there's no match.
- **Label misalignment**: Content prints in the wrong vertical position on the label.
- **Label length not respected**: The printer ignores the `^LL` ZPL command and uses its stored value, causing content to be cut off.

## What We Solved

| Issue | Solution |
|---|---|
| Wrong DPI | Confirmed 203dpi via physical measurement, recalculated all dot values |
| No 105×220mm size | Added custom `PageSize`, `PageRegion`, `ImageableArea`, `PaperDimension` to PPD |
| Vertical misalignment | Set `DefaultzeLabelTop: 35` in PPD |
| Label length ignored | Sent correct `^PW`, `^LL`, `^LT` via ZPL and saved to printer NVRAM with `^JUS` |
| Blank second page on HTML prints | Ghostscript to extract page 1 only |

## Setup

### 1. Find your PPD file

```bash
ls /etc/cups/ppd/ | grep -i zebra
```

Back it up:

```bash
sudo cp /etc/cups/ppd/Zebra_Technologies_ZTC_GK420d.ppd \
        /etc/cups/ppd/Zebra_Technologies_ZTC_GK420d.ppd.bak
```

### 2. Confirm your printer's actual DPI

Print this ZPL test via CUPS in raw mode — it draws two boxes labeled at 203dpi and 300dpi. Measure with a ruler:

```bash
printf "^XA\n^PW400\n^LL400\n^FO10,10^GB80,80,3^FS\n^FO10,100^A0N,25,25^FD10mm@203dpi^FS\n^FO10,150^GB118,118,3^FS\n^FO10,280^A0N,25,25^FD10mm@300dpi^FS\n^XZ" \
  | lp -d <your-printer-name> -o raw -
```

The box that measures 10mm is your actual DPI. The GK420d is **203dpi**.

### 3. Calculate dots for your label size

```
dots = mm ÷ 25.4 × dpi
```

For 105×220mm at 203dpi:
- Width:  105 ÷ 25.4 × 203 = **839 dots**
- Height: 220 ÷ 25.4 × 203 = **1759 dots**

### 4. Find the correct label height

The printer may feed slightly less than the nominal label height. Send a full-size test and measure:

```bash
printf "^XA\n^PW839\n^LL1759\n^FO5,5^GB829,1749,4^FS\n^XZ" \
  | lp -d <your-printer-name> -o raw -
```

Adjust `^LL` until all 4 corners of the frame are visible. We found **LL=1727** for 220mm labels.

### 5. Find horizontal centering

The printhead may not start at the left edge of the label. Test with a narrower frame:

```bash
printf "^XA\n^PW839\n^LL1727\n^FO0,5^GB797,870,4^FS\n^XZ" \
  | lp -d <your-printer-name> -o raw -
```

Adjust the `^FO` x-position and frame width until left and right borders are both visible and centered. We found `FO0` with width `797` worked for our setup.

### 6. Save calibration to printer NVRAM

Once you have the correct values, save them permanently to the printer:

```bash
printf "^XA\n^LH0,0\n^LT-24\n^PW839\n^LL1727\n^JUS\n^XZ" \
  | lp -d <your-printer-name> -o raw -
```

### 7. Add custom label size to the PPD

Edit `/etc/cups/ppd/Zebra_Technologies_ZTC_GK420d.ppd` with sudo. Add these entries (adjust values for your label size):

**After an existing `*PageSize` entry:**
```
*PageSize w298h624/105x220mm: "<</PageSize[298 624]/ImagingBBox null>>setpagedevice"
```

**After an existing `*PageRegion` entry:**
```
*PageRegion w298h624/105x220mm: "<</PageSize[298 624]/ImagingBBox null>>setpagedevice"
```

**After an existing `*ImageableArea` entry:**
```
*ImageableArea w298h624/105x220mm: "0 99 298 624"
```

**After an existing `*PaperDimension` entry:**
```
*PaperDimension w298h624/105x220mm: "298 624"
```

**Update MaxMediaWidth:**
```
*MaxMediaWidth: "298"
```

> **Note on ImageableArea:** The format is `"left bottom right top"` in points (72pt = 1 inch). The `bottom` value offsets content upward. Adjust to match your physical label margins.

### 8. Set vertical alignment default

Find and update the default label top in the PPD:

```bash
sudo sed -i 's/*DefaultzeLabelTop: .*/*DefaultzeLabelTop: 35/' \
  /etc/cups/ppd/Zebra_Technologies_ZTC_GK420d.ppd
```

Restart CUPS:

```bash
sudo systemctl restart cups
```

### 9. Set as default paper size

```bash
lpoptions -p <your-printer-name> -o PageSize=w298h624
```

## Printing HTML labels from a browser

Set **margins = None** in the browser print dialog and select **105x220mm** as paper size.

For automated printing from downloaded HTML files, see [`print-label.sh`](print-label.sh).

## Files

| File | Description |
|---|---|
| `setup.sh` | Automated setup script for 105×220mm labels |
| `print-label.sh` | Print HTML label files via wkhtmltopdf |
| `zebra-print.css` | CSS overrides for correct print layout |
| `calibrate.sh` | Interactive ZPL calibration helper |

## Tested On

- **Printer:** Zebra GK420d (203dpi)
- **OS:** Linux Mint 22.3 / Ubuntu 24.04
- **CUPS:** 2.4.x
- **Label size:** 105×220mm

## Contributing

If you use a different label size or Zebra model, PRs with your calibration values are welcome!

## License

MIT
