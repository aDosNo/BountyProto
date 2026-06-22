# 04 — ECONOMY
Fills the payout/cost slots the generator (02, S8) and nemesis grudge premium
(03) leave blank. Locked principle: **money buys VERBS, not numbers.** Numbers
here are starting ratios to tune in-engine, not gospel. **[NICK]** = your balance
call (most of this doc is, by nature).

## Unit & mental model
Currency = **CR**. The whole economy is balanced around one yardstick: **a clean
baseline contract pays ~1000 CR.** Every price below is expressed as a multiple of
that so the curve holds even if you rescale the absolute number later. Tune the
yardstick first; the ratios should survive.

## Income (what the generator emits at S8)
```
payout = base
       * type_mult          # alive = 2.0, dead = 1.0   (locked)
       * diff_mult          # funnel difficulty D
       * risk_premium       # complication + temperament
       + nemesis_premium    # flat bonus from grudge (03)
       - fines              # wrong-accusation penalty (existing: 500/ea, cap 50%)
```
Starting values:
- `base` = **1000 CR** (the yardstick).
- `type_mult`: dead 1.0 / **alive 2.0** (locked — alive is the hard, lucrative path).
- `diff_mult`: easy 0.8 / standard 1.0 / hard 1.35 / brutal 1.7. Maps off the
  generator's `D`/`k`. **[NICK]**
- `risk_premium`: +0.15 per active complication (rival/double/bribed_faction/curfew),
  +0.1 if temperament is `fight` (dangerous to take alive). Stacks multiplicatively-ish;
  cap ~1.6 so a loaded contract tops out near 1.6×, not infinity. **[NICK]**
- `nemesis_premium`: **+250 CR × grudge** (03). A 4-time escapee is a +1000 CR
  headline bounty on top of difficulty. **[NICK]**
- `fines`: unchanged from BountyManager — 500/wrong accusation, capped at half payout.

Worked example: alive (2.0) × standard (1.0) × one-complication (1.15) = 2300 CR,
+ grudge-2 nemesis (500) = 2800 CR before fines. Feels like a *job*, not a chore.

## Spending — verbs, not stat creep
Two buckets. The split is the whole philosophy: **consumables + capability unlocks
(new verbs)** vs a tiny, deliberately short list of **scalar upgrades**.

### A · Verb sinks (the economy's spine)
One-time unlocks that grant a *new action*, and the consumables that feed them.
Priced so the player is always one or two contracts from the next capability.
| Verb / tool | Type | Cost (CR) | Unlocks the action |
|---|---|---|---|
| Lockpick / decoder | unlock | 800 | open `LockedDoor` shortcuts (existing kit) |
| Grapple / mag-gloves | unlock | 1500 | reach balcony band without built stairs (ties to verticality 01) |
| Disguise tier 1 → 2 → 3 | unlock×3 | 600 / 1200 / 2200 | stronger crowd-blend, more restricted zones |
| Faction permit | unlock (per faction) | 1000 | legal passage through a bribed/hostile checkpoint |
| Lure (noise) | consumable | 120 ea | pull NPCs/guards off a spot (existing `throw_lure`) |
| Bribe | consumable | 300–800 | one guard looks away / one gate opens / one trait from a witness |
| Intel broker reveal | consumable | **600** | **pre-buy ONE trait** before insertion (funnel shortcut, 01) |

Intel-broker pricing is load-bearing: at 600 it's ~60% of a baseline payout to skip
*one* of ~4 narrowing traits — meaningful help, never a "buy the answer" button.
Buying all four would cost ~2400 (more than the standard payout), so brute-forcing
the funnel with cash is a deliberate loss. **[NICK]** confirm that ceiling feels right.

### B · Scalar upgrades (SHORT list — the only numbers money touches)
These are the *exceptions* to "no numbers." Keep this list closed; every addition
dilutes the principle.
| Upgrade | Tiers | Cost (CR) | What scales |
|---|---|---|---|
| Scanner range | 3 | 500 / 1000 / 1800 | confirm from further back (less exposure) |
| Scanner speed/depth | 3 | 500 / 1000 / 1800 | faster lock / reads deeper traits |
| Net range | 2 | 700 / 1400 | capture verb reach (alive path) |
| Binocular tagging | 2 | 600 / 1200 | tag more candidates at once from a vantage |

That's it — four scalar tracks, hard-capped. Everything else is verbs.

## Sinks that aren't power (drains, so income has somewhere to go)
- **Hub cosmetics** (office/ship dressing) — pure money sink, no power. Keeps a
  rich player spending without inflating capability.
- **Staked bond** (below) — risk, not purchase.

## Staked bond (the risk verb)
Optional at contract accept: **stake a bond** to raise the payout, forfeit it on
failure. Starting shape: stake `0.5 × base` (500 CR) → on success refunded +
**1.5× the stake** as bonus (net +750); on failure, lose the 500. A confidence bet
that gives skilled players a faster bankroll and a way to *lose* money, which the
economy needs. **[NICK]** stake sizes / payout multiple.

## Anti-grind / anti-trivial guards
- Payout floor even on sloppy wins (fines cap at 50%) — bad work still pays badly,
  never zero, so failure isn't a soft-lock.
- No repeatable money faucet: contracts are the only real income, and the generator
  controls supply. No farmable spawns.
- Capability gates, not paywalls: every verb unlock is reachable in 1–2 contracts at
  its tier, so progress never stalls behind a grind wall.
- The four scalar tracks cap out, so you can't out-stat the funnel — you still have
  to *play* it.

## Integration points
- **Generator S8** consumes the income formula above; `base`/`type_mult`/`diff_mult`/
  `risk_premium` are the slots it already reserves.
- **NemesisRegistry** grudge → `nemesis_premium` (flat +250×grudge).
- **HunterLedger** (existing `/root/HunterLedger`, `add()`) is the wallet — spending
  needs a matching `spend()/can_afford()` when shops go in (not built yet; flag).
- **BountyManager** fines already implemented and unchanged.

## Open calls reserved for Nick
- The yardstick: is 1000 CR/baseline the right absolute scale?
- `diff_mult` and `risk_premium` curves (shared with 02).
- `nemesis_premium` rate (shared with 03).
- Intel-broker price (600) and the "all-four costs more than the payout" ceiling.
- Staked-bond stake size and payout multiple.
- Disguise/grapple/permit absolute costs — these set the early progression pace.
