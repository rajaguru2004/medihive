# MediHive — Design system

**Chart & Vitals.** A flat, inset-grouped clinical surface lit by one cool
brand colour.

This file is the contract. `lib/app/theme/` is its executable form — a screen
that hand-rolls something the kit already provides is a defect, not a
variation. `.agents/RULES.md` §2 is the enforcement checklist; this is the
reasoning behind it.

---

## 1. The world

A ward board is not a dashboard. It is read across a corridor, at 3am, by
somebody who has been awake fourteen hours and is looking for one thing: is
anybody in trouble. Everything below follows from that.

**Light** is cool clinical paper (`#F4F6F7`), white inset surfaces, teal
reserved for action. Not the warm paper of a ledger app: a screen read for a
twelve-hour shift wants the glare off it.

**Dark** is deep slate (`#0C1114`), raised surfaces, teal lifting off them. Not
pure black — a raised surface needs somewhere to go, and pure black smears on
an OLED panel when it scrolls.

Both are real usage. Dark is not a preference here; it is the night shift.

---

## 2. Colour

### 2.1 The two rules

**Teal is the brand, never an acuity.** Status lives in its own ramp with no
teal in it. A teal "stable" pill beside a teal primary button makes the brand
unreadable as an affordance.

**Red means one thing.** `acuityCritical` and `error` are the only reds in the
app. Not a chart series, not a decorative accent. A clinician scans for red;
every red that is not a deteriorating patient costs that scan its meaning. A
missed appointment is amber — an administrative problem, not a patient one.

### 2.2 The brand

| Role | Value | Use |
|---|---|---|
| `primary` | `#0E7C7B` | The brand as a **fill** — CTAs, the active tab |
| `primaryDark` | `#0A5F5E` | Pressed |
| `primaryLight` | `#CCE7E6` | Soft fills behind brand elements |
| `accent` | `#0070C0` | Ledger blue — billing, never a clinical state |

`#0E7C7B` measures **4.63:1** on the paper ground and passes; the same value on
the deep-slate ground is **3.79:1** and does not. That asymmetry is the whole
argument: a brand that looks fine in the mode its designer was working in is
unreadable in the other one, and which way round it fails is not predictable
from looking at it. So the brand is never used as text directly. `BrandPalette`
derives two roles against the ground each will actually sit on:

- **`ink`** — the brand as words and icons, walked toward the ground's opposite
  until it clears 4.5:1. `brandInkColor(context)`.
- **`fill`** — the brand as a solid shape: **the brand itself, always**. A teal
  button has to be teal. The 3:1 boundary a filled control owes a viewer is
  paid by `fillEdge` — a hairline in a deeper shade — while `onFill` guarantees
  the label on top is legible.

Hue and saturation are untouched, so a derived ink is a darker teal, not a
slate. A brand that already passes is returned unchanged.

### 2.3 The acuity ramp

Ordered by urgency, because that is the order a clinician reads them in.

| Token | Value | Means |
|---|---|---|
| `acuityCritical` | `#DC2626` | Deteriorating, or triaged immediate |
| `acuityUrgent` | `#EA580C` | Seen soon, not now |
| `acuityReview` | `#7C3AED` | Waiting on a clinician's sign-off |
| `acuityStandard` | `#0070C0` | Triaged, waiting, nothing flagged |
| `acuityRoutine` | `#64748B` | Non-urgent, or the resting state |
| `acuityStable` | `#16A34A` | Observed and stable — the good outcome |
| `acuityDischarged` | `#94A3B8` | Off the board |

`acuityReview` is violet rather than the amber the state suggests, because
amber is `warning` and "waiting for review" is not a warning. It is a queue
position.

### 2.4 Bed states

A bed grid is read as a map, so its states get fills rather than pills — but
they are drawn from the same vocabulary so the two views of one ward agree.

`bedVacant` `#16A34A` · `bedOccupied` `#0070C0` · `bedReserved` `#7C3AED` ·
`bedBlocked` `#94A3B8`

`BedState.resolve` reads unknown states as **blocked**, not vacant: a bed
nobody can account for must not be offered to the next admission.

### 2.5 Using a ramp colour as text

The ramp is chosen for a light ground. On ink it fails: `#0070C0` on a dark
card is 2.7:1. **Every ramp or semantic colour used as a word goes through
`semanticInk(context, colour)`.** Fills and legend dots keep the raw colour —
they are seen, not read.

---

## 3. Typography

One eleven-step scale, borrowed from Apple's HIG because it is the scale both
platforms' users already read at. Light and dark variants of each, differing
only in colour, so a widget picks by brightness and never hand-mixes.

```
largeTitle 34 → title1 28 → title2 22 → title3 20 → headline 17
→ body 17 → callout 16 → subheadline 15 → footnote 13
→ caption1 12 → caption2 11
```

### 3.1 Figures

**Anything that lines up in a column or ticks is tabular.** A proportional `7`
is narrower than a `0` in every bundled face, so a column of observations
visibly shivers as it refreshes — and a heart rate that shivers is one somebody
reads twice.

- `AppTextStyles.vital(...)` — an observation. Never the money weight: a figure
  a clinician acts on is set at the weight of its row, so the *colour* is free
  to carry acuity. Bold **and** red reads as two alarms.
- `AppTextStyles.unit(...)` — the unit beside it. A step down, tertiary, same
  weight, so the pair reads as one object.
- `AppTextStyles.money(...)` — billing only.
- `AppTextStyles.overline(...)` — the only place letter-spacing opens up.

### 3.2 The weight axis

Flutter does not map `FontWeight` onto a variable font's `wght` axis by itself,
and the default instance is not 400 for half the registry — **Montserrat's is
Thin**. `AppFonts.text` applies the axis unconditionally, which is the single
line standing between this app and hairline body copy.

This is why `copyWith(fontWeight: …)` is banned: it moves the weight and not
the axis, so the text claims bold and draws regular.

---

## 4. Material and depth

### 4.1 Glass without a blur

There is **not one `BackdropFilter` in this app**. A card is glass here through
a translucent, top-lit fill over the ground's ambient wash, a luminous
hairline, and one soft shadow.

A blur reads back and re-blurs everything under it on every frame the content
moves. Forty of them in a list is the most expensive thing a Flutter screen can
do, and on a ward tablet running a board that refreshes every thirty seconds it
is a cost paid continuously for decoration.

### 4.2 The ambient wash

`BentoGround` pre-blends the site's brand into the ground as one gradient — the
same cost as the flat colour it replaces. On dark the brand is lightened before
blending: deep teal laid straight onto near-black makes a muddy green, because
what survives at 15% is its hue and none of its luminance.

### 4.3 Shadow and hairline

One soft ambient shadow, with a real offset and blur. `hero` is reserved for
the single card on a screen allowed to sit higher than its siblings. The
hairline is never dropped and never coloured: it is what makes a white card
legible on cool paper and an ink card legible on ink.

---

## 5. Rhythm

`BentoSpace`: page 16 · section 18 · header 10 · cardPad 20 · listPad 14 ·
listCardPad 8 · action 12.

`BentoRadius`: rule 3 · band 5 · track 8 · small 10 · pill 12 · control 16 ·
card 20 · hero 24 · sheet 28.

`AppTheme.minTapTarget` is **48**, which satisfies Material's 48 and Apple's
44 at once. No exceptions — some of these users are wearing gloves.

---

## 6. The kit

### 6.1 Structure

```
Screen shell  → BentoScreen(slivers:), BentoSection, BentoGround, MaxWidthBody
Cards         → BentoCard, BentoRow, FactRow, InsetSurface, Hairline
Figures       → VitalFigure, VitalTile, VitalsGrid, MoneyFigure, RatioBar, UsedBar
Status        → StatusPill, StatusMark, CountBadge, CaseStatus
States        → EmptyState, ErrorRetryBanner, NoticeBanner, BentoSkeleton
Actions       → PrimaryBar, SecondaryBar, ActionCard, QuickActionTile
Navigation    → DetailHeader, SectionHeader, FilterChips, CircleIconButton
Forms         → FormCard, BentoField, BentoInput, BentoPicker, BentoSegmented
Sheets        → SheetShell, SheetRow, ConfirmDialog
```

### 6.2 The clinical layer

`app_bento_clinical.dart` is the part only a hospital needs. It exists so that
the three screens showing a bed, the four showing an acuity and the two showing
a wait all show them the same way.

| Component | What it is for |
|---|---|
| `AcuityPill` | A triage level: colour, **rank** and word together |
| `AcuityLegend` | The key, once, under the board |
| `VitalFigure` / `VitalTile` / `VitalsGrid` | Observations, left-aligned so the eye runs down a column |
| `VitalInput` | Entry that colours its **unit** when out of range |
| `VitalRange` | The one place an observation is judged normal |
| `WaitChip` | Elapsed wait, turning past the site's breach threshold |
| `QueueTicketRow` | Position, identity, acuity, wait |
| `BedState` / `BedTile` / `BedGrid` | A ward as a floor plan |
| `WardCapacityBar` | Four-state census in one bar |
| `PatientIdentityBand` | Who, which record, how old, what state |

### 6.3 Rank, not just colour

`AcuityPill` carries its P-code as a glyph and `BedState` carries an icon,
because colour alone fails three readers at once: somebody colour-blind,
somebody reading a black-and-white printout of the board, and somebody standing
too far away to resolve a tint. A triage level *is* an order, and the order is
the whole point.

### 6.4 Where colour goes on a form

`VitalInput` colours its **unit**, never its border. A red border in a form
already means "this field is invalid", and 39.8 °C is a perfectly valid entry
describing a patient with a fever. A form that uses one signal for both teaches
its users to ignore one of them.

---

## 7. Motion

One authored moment per interaction, and all of it through
`motionDuration(context)`, which honours Reduce Motion — the e2e harness turns
it on, so an animation that ignores it hangs the suite.

The vocabulary is small on purpose: an `easeOutCubic` tint-and-scale on a
selected control, a cupertino push between screens, a shimmer on first load.
Nothing enters on scroll. A board that animates while somebody is reading it is
a board that costs them a second every time.

---

## 8. States

Every list has four, and all four are designed:

- **First load** — `BentoSkeleton`, in the shape of the content.
- **Empty** — `EmptyState` says what would be here and offers the action that
  would put something here. A filtered empty offers "clear filters" instead.
- **Error** — `ErrorRetryBanner`, inline and persistent, with the retry
  attached. Never a toast: a toast disappears in three seconds and takes the
  retry with it, leaving an empty list that looks like "nobody is waiting".
- **Loaded** — the content.

A refresh is **silent**: the board a clinician is reading stays on screen
rather than collapsing to a skeleton under their thumb.

---

## 9. Voice

Plain, specific, and about the patient rather than the system.

- "Nobody is waiting", not "No records found".
- "Bed 04 is free", not "Operation completed successfully".
- "That did not work. Check your email and password, then try again." — names
  the problem and the recovery.
- A confirm names the person: "Discharge Tom Whitfield?" and then says what
  becomes true: "Bed 01 is freed and the admission is closed."

No exclamation marks. No "oops". Nobody on a ward at 3am wants to be cheered
up by a form.
