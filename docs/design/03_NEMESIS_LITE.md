# 03 — NEMESIS-LITE
The persistence layer for escaped targets. Generator-independent core; integrates
at generator S1′ (see 02) and a BountyManager escape hook. "Lite" = one small
persisted roster, simple mutation, no Nemesis-system hierarchy. **[NICK]** = your
balance/design call.

Status (2026-07-01): `NemesisRegistry` is an autoload and the roster/mutation
code exists. Explicit target escape and BountyManager record/clear hooks also
exist. Recording is intentionally disabled in the live scene because the
hand-authored target exposes `scanner_signature`, while the registry contract
requires canonical `scanner_sig` plus a generator-owned trait kit. Re-entry
still depends on the unbuilt contract generator.

## Identity model (the one idea everything hangs on)
A nemesis is the **same individual** returning, so their identity anchor must
persist while their *tells* change:
- **`scanner_sig` PERSISTS** — it is the biometric individual. This is how the
  scanner confirms "it's them, again." Never mutates.
- **`base_id` PERSISTS** — same species/build.
- **Narrowing traits MUTATE** — appearance (new disguise), location habit (new
  turf), gaze/path tells (new behavior). Your old intel notes go stale; that's the
  point of a recurring rival.
- **Wound → physical tell, PERSISTS and can worsen.** If the player *wounded* the
  target last encounter, that becomes a permanent movement tell (a limp) carried
  into every future re-entry — the grudge made flesh, and a fair "you hurt me, now
  I'm easier to spot but angrier" tradeoff. Behavioral tells re-roll; physical ones
  stick.

## Persisted struct (one roster, capped)
```yaml
nemesis_entry:
  scanner_sig          # identity key (persists)
  base_id              # build (persists)
  alias                # flavor ("the one who got away")
  grudge               # 0..GRUDGE_MAX; drives difficulty/complication/payout
  times_escaped
  physical_tell        # movement_tell_id if ever wounded, else null (persists)
  last_district
  last_appearance      # so re-entry can pick a DIFFERENT palette
  active_in_contract   # guard so the same nemesis isn't drawn into two contracts
```
Stored as a single roster file (`user://nemesis_roster.save`), capped at
`MAX_ROSTER` **[NICK]** (default 3 — "lite" = a couple of recurring rivals, not a
sprawling cast). Lowest-grudge entry is evicted when full.

## Lifecycle
1. **Record** — contract ends with the target **alive + identified** → write/update
   the nemesis entry (grudge++, capture physical tell if wounded). *(Trigger is a
   [NICK] call — see below.)*
2. **Persist** — roster saved to disk; survives across sessions.
3. **Inject** — generator S1′ checks `has_pending_nemesis()`; if so, pulls a
   **mutated** trait_kit + difficulty bump instead of rolling a fresh target, and
   marks it active.
4. **Clear** — nemesis finally caught/killed → removed from roster (their story
   ends). Until then they keep coming back harder.

## Mutation on re-entry
| trait_kit field | On re-entry |
|---|---|
| `scanner_sig` | **persist** (identity anchor) |
| `base_id` | **persist** |
| `appearance.palette_id` | **mutate** — pick a value ≠ last_appearance (new disguise) |
| `location_habit_id` | **mutate** — new turf |
| `movement_tell_id` | **conditional** — if `physical_tell != null` use it (persists, from wound); else re-roll behaviorally |

The generator passes its district's trait pools (palette/location/movement) into the
mutation so re-entry only picks values the *current* district supports.

## Grudge scaling ("harder")
`grudge` (0..GRUDGE_MAX) emits a bump the generator consumes:
- **`difficulty_bonus = grudge`** → generator maps onto `k` / `n_*` (more
  near-twins, tighter funnel — see 01/02 difficulty params). **[NICK]** the curve.
- **`force_complication`** at high grudge → bodyguard / bribed_faction / a `rival`
  escort. A 4-time escapee shouldn't walk the street undefended.
- **Payout premium** — a known recurring mark pays more (feeds 04 economy).

## Integration points (and what's gated)
- **Record hook — BountyManager.** BUILT but gated by
  `nemesis_recording_enabled = false`. `_on_target_escaped()` calls the hook;
  enabling it still requires a canonical `scanner_sig`/trait-kit profile.
- **Inject hook — generator S1′.** `roll_nemesis_entry(rng, palette_pool,
  location_pool, movement_pool)`. Exists in the registry now; no caller until the
  generator does.
- **Clear hook — BountyManager.** BUILT on capture/neutralization and controlled
  by the same export gate.

## Escape trigger decision

Option B was implemented: prepared chase routes can emit
`KorvaxiTarget.escaped(route_id)`, and BountyManager records a distinct
`target_escaped` failed outcome. Wrong accusation still transforms the live
mission and does not itself create a nemesis. Hunter death/abandon behavior
remains a separate future ruling.

## Open calls reserved for Nick
- `MAX_ROSTER` (default 3) and whether grudge **decays** over time/contracts.
- `GRUDGE_MAX` and the grudge→difficulty curve (shared with 01/02).
- Does a wound *always* become a permanent tell, or only a serious one?
- Whether hunter death or contract abandonment should also record an escape.
