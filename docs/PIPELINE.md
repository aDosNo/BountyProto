# PIPELINE — How to build the map without it becoming bloated

The standing reference for how `bounty-hunt` districts get built. Applies to
Claude, Codex, and Nick. The goal: support immersive-sim depth + verticality
across 2–3 districts **without** every scene collapsing into thousands of bespoke
hand-placed meshes. Read this before adding geometry to any map.

Status (2026-07-01): this is the target workflow. The live Hesperus scene is
mid-migration and still generates collision for many imported GLBs.

## The one principle: keep three layers separate
Bloat comes from fusing things that should be independent. Every district is
three layers that must never be tangled:

1. **Collision / navigation** — the playable volume. Floors, walls, ramps, the
   ledge you actually stand on, nav. Ugly gray boxes. **Tuned for gameplay.**
2. **Visual** — what it looks like. Building shells, grime, neon, silhouette.
   **Tuned for looks.** Carries NO collision.
3. **Logic** — spawns, clues, doors, triggers, AI routes, funnel/contract data.
   Declared independently of geometry (see the district_descriptor in
   docs/design/02_CONTRACT_GENERATOR.md).

If a change to one layer forces a rebuild of another, the layers are fused and
that is the bug.

## Build order (whitebox-first — non-negotiable)
This is how Arkane/Deus Ex-lineage studios actually work. Strict order, with a
**playtest gate** between each stage. Never skip ahead.

**Stage 1 — Whitebox (pure collision, zero art).**
Build the whole area from untextured boxes + ramps representing ONLY playable
volume and navigation. No buildings, no GLBs, no neon. Just: here is a floor,
a wall, a ramp to the second floor, a ledge, a drop.
- **This is where verticality and im-sim routes are designed.** The
  five-routes-to-one-objective, the funnel sightlines, the chase paths — all
  decided here, in cheap gray boxes, and **playtested until the movement itself
  is fun.** Stay in whitebox longer than feels comfortable.
- Layout belongs to Nick. Whitebox is the layout.

**Stage 2 — Modular kit (visual shells that wrap the whitebox).**
Build a SMALL library of reusable pieces — wall, window-wall, railing-2m, stair,
awning, pillar, deck-segment, kiosk — each on a grid (2m/4m). "Skin" the whitebox
by snapping/instancing kit pieces onto it.
- A market street is NOT 400 unique boxes. It is ~8 wall variants + ~5 prop
  types **instanced hundreds of times.** ~25–40 kit pieces for a whole district.
- This is the answer to the bloat fear: **stop authoring unique geometry, start
  placing instances of a finite kit.** Districts 2–3 are recombinations of the
  same kit → almost no new modeling.

**Stage 3 — Set dressing (the unique, hand-placed character).**
ONLY after the kit skins the whitebox: hand-place one-off details — the specific
sign, the crate pile in this corner, the stain. Allowed to be bespoke because
it's thin (a few % of geometry) and touched last.
- Set dressing must NEVER dictate where a wall goes. Whitebox is sacred; art
  conforms to it, not the reverse.

## The hard rule for THIS project (Godot)
We were doing it backwards: Blender set-pieces carried gameplay collision via
`auto_collider`. That fusion is the trap. Going forward:

- **`.tscn` graybox geometry = source of truth for collision + layout.**
  Floors, walls, ramps, the deck you stand on = simple `StaticBody3D` + explicit
  `BoxShape3D`, living in the scene, tuned for gameplay. This is the whitebox and
  it is what you playtest. `BazaarFloor`, `WalkwayNorth`, the ramps already are
  this — treat them as authoritative for WHERE things are.
- **GLBs = visual-only shells, collision OFF, positioned to wrap the graybox.**
  The street GLB, gallery, building masses become decoration that conforms to the
  gray boxes. Turn off `auto_collider` on them; the boxes underneath do the
  physical work. Change layout = move a gray box + playtest now; art catches up
  later.
- **Logic lives in nodes + data files**, not baked into meshes (traits/contracts
  already follow this — keep it consistent for doors/triggers/routes).

Why: if im-sim/verticality logic is trapped inside expensive Blender exports, you
iterate slowly and the design calcifies before it's fun. Cheap gray boxes =
fast iteration = good im-sim design. The separation is what makes the whole
design tractable for one person.

### Carve-out: `auto_collider` as the GLB material-applicator

`scripts/auto_collider.gd` is doing two unrelated jobs and the distinction
matters. **Collision generation** (the script's original purpose) is the
fusion trap — `.tscn` graybox owns collision; GLBs do not. **Material
application by name-match** (floor materials, the window-glass warm/cool
tint) is the opposite: it's a thin runtime hook that keeps art data out of
the Blender export and in the project's `.tres` files, which is exactly the
layer separation this doc preaches.

The bridge state, until a building has a confirmed graybox underneath:
- Leave the `auto_collider` script attached to building GLBs.
- `enabled = true` while the graybox is missing (script generates collision
  as a stopgap so the scene is walkable).
- Once a graybox slab is authored beneath the GLB and verified in playtest,
  set `enabled = false` on that building. Collision drops out; the floor /
  window / accent material hooks keep working.
- Hidden-mesh prefixes and material exports stay as-is — they're the
  material/visibility layer, not the collision layer.

This means "retrofit `auto_collider` off" is a **per-building toggle**, not a
script removal. The script lives until every building has graybox under it;
then the collision branch can be deleted and only the material branch
remains.

Two current exceptions must not be mistaken for the finished architecture:

- `HoloCantina` uses authored `HC_collision_*` proxy meshes from its GLB.
- `Hesperus_Market2_Street_gallery` uses authored `GAL_collision_*` proxies;
  its five June 30 modular stalls are assembled in Blender and exported with the
  gallery.

These proxies are materially better than generating collision from every visual
mesh, but collision is still coupled to the GLB export. Keep them until explicit
Godot graybox replacements are playtested; do not claim the layer migration is
complete.

## Anti-bloat checklist (apply before adding geometry)
- Am I about to hand-place unique meshes that should be kit instances? → make/
  reuse a kit piece instead.
- Is this mesh going to carry collision AND visuals? → split it: graybox box for
  collision, GLB for looks.
- Am I designing a route/sightline in expensive art? → do it in whitebox first.
- Is set dressing dictating a wall position? → stop; fix the whitebox, redress.
- Did I just write a 400-box Python generator for a new district? → that's
  bespoke-everything returning; build a kit and instance it.

## Retrofit policy (don't big-bang it)
A full "re-architect the whole map" pass is itself the over-engineering trap.
Instead:
- **All NEW work** adopts the layer separation immediately.
- **Existing district** is retrofitted opportunistically. First natural retrofit:
  the East side — remove the orphaned `EastBalconyRun` .tscn nodes + stale
  orphan-balcony-era lights now that the real gallery GLB exists, and confirm the
  graybox under the gallery owns collision while the GLB is visual-only.

As of 2026-07-01 `EastBalconyRun` still exists and the gallery still owns proxy
collision, so this remains proposed cleanup rather than completed work.

## Where this connects
- **Verticality bands + measured layout:** docs/level_design/01_VERTICALITY_PLAN.md
- **Logic-as-data (the same separation, for gameplay):**
  docs/design/01_TRAIT_FUNNEL_MATRIX.md, 02_CONTRACT_GENERATOR.md
  (district_descriptor = the logic layer declared independent of geometry).
- **Blender workflow:** backups before edits, export GLB to the instanced path,
  never `save_as_mainfile` over an original — save under a new name.
