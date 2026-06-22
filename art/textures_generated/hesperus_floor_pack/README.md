# Hesperus Market floor texture pack

Eight square PNG floor textures extracted from the supplied floor-reference
sheet. Each texture is provided at 64x64, 128x128, and 256x256. The numbered
size directories contain the closest-reference crops. `seamless/` contains
edge-reconciled versions whose opposite borders match exactly.

The 256px files retain the most reference detail. Use the 128px set for the
closest balance of Build-engine-style pixel density and in-game readability.
Use nearest-neighbor filtering in-engine when a hard pixel edge is desired.

Contents:

1. Dock metal floor plate
2. Dock metal floor plate, damaged
3. Bazaar stone paver
4. Bazaar stone paver, dirty
5. Catwalk grate
6. Catwalk grate with green under-light
7. Service concrete
8. Service concrete with hazard stripe

Rebuild command:

```bash
python tools/extract_hesperus_floor_pack.py \
  /path/to/reference.png \
  art/textures_generated/hesperus_floor_pack
```
