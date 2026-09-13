# MediHive — working agreement

Read [.agents/RULES.md](.agents/RULES.md) before writing any code here. It is
the contract; this file is only the short version plus how to work in this
repo.

## Read these first

| File | What it settles |
|---|---|
| `.agents/RULES.md` | The non-negotiables. **§0 is patient safety** |
| `DESIGN.md` | The visual world, and why each rule exists |
| `PRODUCT.md` | Who holds the device and what the backend answers with |
| `docs/TASK_TRACKER.md` | Where the work got to, and the bugs it found |

## The three rules that outrank everything

1. **Red means one thing** — `acuityCritical` or `error`. Never a chart series,
   never decoration, never a delete that is not destructive.
2. **Teal is the brand, never an acuity.**
3. **A clinical state is colour *and* rank *and* word**, never colour alone.

## The gate

Every change. No exceptions, no "known" failures:

```sh
flutter analyze                 # must be zero issues
flutter test test/              # unit tier
dart run tool/check_keys.dart   # unkeyed count may only go down
```

On a device, when UI changed:

```sh
flutter test integration_test/suites/smoke_suite.dart -d <device>

flutter drive \
  --driver=test_driver/screenshot_driver.dart \
  --target=integration_test/screenshots/review_screenshots_test.dart \
  -d <device>
```

## Traps this codebase has already been bitten by

Each of these cost a debugging session once. They are in the source with
comments; repeated here because they are invisible until they bite.

- **`await Get.toNamed(...)` hangs.** It completes when the route is *popped*.
  Awaiting it in a test, or anywhere that then wants to pop it, waits forever.
- **A `GetView` whose build never reads `controller` never builds it.** A
  `lazyPut` controller doing its work in `onReady` will simply never run. The
  splash screen hung on this.
- **`copyWith(fontWeight:)` moves the weight and not the `wght` axis**, so the
  text claims bold and draws Thin. Ask the factory for the weight.
- **Deriving rank from colour ties any two states that share one.** The triage
  sort did this and silently fell back to arrival order.
- **This backend stores an unobserved numeric vital as `0`.** Guard `<= 0`, not
  just null, or an unrecorded temperature renders as hypothermia.
- **`Opacity` over live text is a contrast bug**, not a styling choice. Mute
  with a token.
- **Never ellipsise a clinical figure.** `16…` could be 160, 168 or 16.

## Working style

- Use Read/Write/Edit directly rather than shelling out — `.claude/settings.json`
  allows them, and the file tools give better diffs.
- Comments explain **why**, never what the line below does. Match the density
  of the surrounding file; `lib/app/theme/brand_palette.dart` is the register.
- `flutter analyze` clean before you say you are done.
