# SpendAnalyzer

A private, offline-first expense tracker for iOS. No account, no bank login, no server — every transaction stays on the device.

I built it because every finance app I tried wanted my bank credentials before it would do anything. This one asks for nothing and makes no network calls at all.

---

## What it does

- Log expenses and income in a few taps, with a custom numeric keypad built for speed
- Categorise spending (food, transport, bills, gym, and custom categories you add yourself)
- Track money sent to and received from people, pulled from the system contact picker
- See spending over days, weeks, months, or years in a scrollable chart
- Set a monthly budget and watch what's left
- Export everything to CSV — it's your data
- Face ID lock (see *Security*)

---

## The parts worth reading the code for

### Siri shortcut across a process boundary

Saying *"log an expense in SpendAnalyzer"* should open the app straight into the add-expense screen. The catch: **an App Intent runs in a separate process from the app**, so it can't reach into a running UI and present a sheet directly.

The intent writes a flag to shared storage, and the app watches for that flag in two places:

- `onAppear` — for when the app launches cold from the shortcut
- `onChange(of:)` — for when the app is already running in the background

Both paths are needed because either can happen depending on the app's state. The flag resets the instant the sheet opens, so the next launch doesn't re-trigger it.

`Intents/SpendShortcuts.swift`, `MainTabView.swift`

### The analytics chart

A horizontally scrollable [Swift Charts](https://developer.apple.com/documentation/charts) bar chart whose visible window resizes with the time filter — one week for *Days*, five weeks for *Weeks*, six months for *Months*, four years for *Years* — so bars stay a readable width instead of shrinking to slivers.

Tapping the chart maps the tap position back to a date, snaps to the nearest bar, and dims the rest. A dashed rule marks the average.

**Colours are assigned by spend rank, not category name**, so within a view the biggest category keeps one colour across the chart, the summary row, and the ranked list below.

`AnalyticsView.swift`

### Indian number formatting

Every amount is formatted with the `en_IN` locale, so it groups as `1,00,000`, not `100,000`.

---

## Tech

- **Swift / SwiftUI**
- **SwiftData** for on-device persistence (`@Model` on `Transaction` and `BudgetHistory`)
- **Swift Charts** for the scrollable, tappable analytics
- **App Intents** for the Siri shortcut
- **ContactsUI** for people-based tracking
- No third-party dependencies. No networking.

---

## Security

Unlock is currently a PIN, which is **not** real security — the value lives in code and could be read from the binary.

I'm replacing it with **Face ID via `LocalAuthentication`**, with the device passcode as fallback. Until that lands, treat the lock as a convenience, not a guarantee.

---

## Known limitations

- PIN lock, being replaced with Face ID (above)
- Payment accounts are declared in more than one place, which forces the analytics filter to match on substrings; collapsing this to a single source of truth
- Category colours are rank-based, so they shift as spending changes, and the palette holds six entries — a seventh category reuses a colour. A fixed colour per category fixes both

---

## Build

Open `SpendAnalyzer.xcodeproj` in Xcode and run on an iOS 17+ simulator or device. SwiftData and Swift Charts require iOS 17.

No configuration, no keys, no backend to stand up.
