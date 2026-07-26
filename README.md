# CalcBook

A premium Material 3 calculator for Android, built with Flutter. Its core
feature is **Calculation Sheets** — save any live expression trail as an
independent, reloadable workspace, manage them from a slide-up Sheet
Manager (rename, delete, reorder, reload), and switch between Standard and
Scientific (sin, cos, tan, log, ln, √, xʸ, parentheses) modes.

## Architecture

MVVM, mirroring the original native spec 1:1 in Flutter terms:

| Native concept          | Flutter equivalent                                   |
|--------------------------|--------------------------------------------------------|
| Room Entity              | `CalculationSheet` (`lib/models/calculation_sheet.dart`) |
| Room Entity (history)     | `CalculationHistoryEntry` (`lib/models/calculation_history_entry.dart`) |
| Room DAO / Database      | `DatabaseHelper` — sqflite (`lib/data/database_helper.dart`) |
| exp4j evaluator          | `ExpressionEvaluator` — `math_expressions` (`lib/services/expression_evaluator.dart`) |
| ViewModel + StateFlow    | `CalculatorProvider` — `ChangeNotifier` (`lib/providers/calculator_provider.dart`) |
| Compose UI               | Flutter widgets (`lib/widgets/`, `lib/screens/`)      |

```
lib/
├── main.dart                       # App entry point, Provider + MaterialApp wiring, edge-to-edge UI
├── models/
│   ├── calculation_sheet.dart          # Room-equivalent entity (id, title, expression, displayOrder)
│   └── calculation_history_entry.dart  # Auto-logged history entity (id, expression, result, timestamp)
├── data/database_helper.dart       # sqflite DAO: Sheets CRUD + reorder, History CRUD + auto-pruning
├── services/expression_evaluator.dart  # Scientific-capable expression parser
├── providers/calculator_provider.dart  # ViewModel: active state, sheet ops, history logging
├── theme/app_theme.dart            # Material 3 light/dark theme + system chrome sync
├── screens/calculator_screen.dart  # Main screen: no-scroll layout, Standard/Scientific segmented toggle
└── widgets/
    ├── calc_button.dart            # Single key, tonal M3 styling, haptic feedback
    ├── calc_button_grid.dart       # Flexible Expanded-row grid — always fits the screen, never scrolls
    ├── display_panel.dart          # Expression/result readout
    ├── sheet_manager_drawer.dart   # Save / reload / rename / delete / reorder UI
    └── history_drawer.dart         # Auto-logged calculation history: reuse / swipe-delete / clear-all
```

### UX notes on this revision
- **Scientific toggle** is now a labeled `SegmentedButton` ("Standard" / "Scientific") instead of an unlabeled switch, so the mode is always explicit.
- **Sheets access** moved from a floating action button into an AppBar icon with a count badge — it no longer overlaps the button grid.
- **No-scroll layout**: the display and button grid use flex-based `Expanded` sizing so the whole screen always fits the viewport, exactly like a native calculator app — toggling Scientific mode adds rows that share the same space rather than pushing the layout off-screen.
- **History**: swipe up on the display (or tap the History icon in the AppBar) to open a drawer of every past calculation, auto-logged on every "=". Tap to reuse, swipe to delete one, or clear all — independent from your curated Sheets.
- **System chrome** (status bar / navigation bar icon color) now syncs with light/dark mode automatically via `AppTheme.systemOverlayStyle`.

### Round 8 — second sanity-check pass
This pass specifically hunted for second-order UX surprises rather than re-checking what Round 7 already covered. Five real issues found and fixed:
- **"AC" was silently exiting the active sheet.** `clearAll()` reset `activeSheetId` to null as a side effect, meaning clearing a mistyped number while working in a sheet would unexpectedly detach you from it — even though there's a dedicated, explicit × on the sheet chip for that. AC now only clears the display, full stop.
- **Orientation wasn't locked.** The entire layout (flex ratios, dialog sizing, button proportions) was designed portrait-only; rotating to landscape would have produced a genuinely cramped, broken-looking layout. Locked via `android:screenOrientation="portrait"`.
- **Long sheet titles could overflow.** The list tile's title `Text` had no `maxLines`/`overflow` (unlike the expression/description lines right below it, which already had this), and the active-sheet chip on the display had no width constraint at all — `overflow: TextOverflow.ellipsis` does nothing without a bounded width to ellipsize against. Both fixed; added a 60-character title cap (`CalculationSheet.maxTitleLength`) as a second line of defense, enforced both in the dialog's `TextField` and in the provider (`_clampTitle`), mirroring how description was already capped.
- **Editing a sheet with an empty title failed completely silently.** `updateSheetDetails` would just `return` early with zero feedback — the dialog had already closed, so the user had no idea their edit wasn't saved. The Save/Edit dialog is now a `StatefulBuilder` that shows an inline "Title is required" error and disables the confirm button until the title is non-empty, so this can't happen anymore — it's prevented at the point of submission instead of failing silently afterward.

### Round 7 — production readiness audit
Full sanity pass across the whole app; see `CalcBook_Production_Readiness_Audit.md` for the complete report. Two real bugs were found and fixed:
- **CI would have failed**: `.github/workflows/build_apk.yml` was still pinned to Flutter 3.24.0, which predates `DialogThemeData` (required since 3.32, used in `app_theme.dart` since Round 4). Bumped to 3.44.6.
- **`flutter test` would have failed**: `CalculatorProvider` talks to `sqflite` on construction, but plain `flutter test` has no platform channel for it. Added `sqflite_common_ffi` as a dev dependency and initialized it in `test/widget_test.dart`; also hardened the provider's startup DB loading with try/catch so a DB-open failure can't crash the app on launch, and expanded the test suite from 2 to 3 test cases.

Also verified (no changes needed): the calculation engine against a 46-case test battery, both DB migration paths against real SQLite, cascade-delete behavior, every provider method has exactly one real UI call site, all imports resolve, package naming is consistent across Gradle/Kotlin/Manifest, and Gradle/AGP/Kotlin/SDK versions remain mutually compatible.

### Round 6 fixes
- **Save/Edit sheet dialog no longer resizes while typing**: the dialog previously had no explicit width constraint, so the description field's `maxLength` counter text (e.g. "123/250") could make the dialog's intrinsic width grow as you typed. It's now a fixed 360×200 landscape-ratio box (`SizedBox` + `SingleChildScrollView` in `_showSheetDetailsDialog`, `lib/widgets/sheet_manager_drawer.dart`) — stays the same size regardless of what's typed, and the scroll view keeps it safe from overflow if the keyboard shrinks available space.
- **Background no longer shifts when the Edit-sheet keyboard opens**: the main calculator `Scaffold` was reacting to the keyboard's viewInset even though the actual text field lives in a dialog on top, which handles its own keyboard avoidance independently. Set `resizeToAvoidBottomInset: false` on the main screen's `Scaffold` (`lib/screens/calculator_screen.dart`) — the calculator screen has no text inputs of its own, so it never needs to respond to the keyboard.

### Round 5 — new features
- **Sheet descriptions**: sheets now have an optional short description (max 250 chars) alongside the title. Editing a sheet (tap the edit icon) opens a dedicated "Edit sheet" dialog for both fields, replacing the old inline-rename swap — a multi-line description doesn't fit cleanly into an inline `ListTile` edit, so a small dialog (shared with the "Save as new sheet" flow, via `_showSheetDetailsDialog`) keeps both flows consistent. The description shows as a compact, muted, max-2-line preview under the sheet's expression in the list — capped so it can never dominate the row or make the list feel cluttered.
- **Two-scope history**: History is now split into *General* history (calculations made outside any sheet) and each sheet's *own* history — logged automatically based on whichever sheet (if any) was active when "=" was pressed (`CalculatorProvider._logHistory` tags each entry with `sheetId`). "Clear all" only ever clears the list currently showing, never both.
- **Context-aware swipe-up**: swiping up on the display (or tapping the AppBar History icon) opens *General* history when no sheet is loaded, or *that sheet's* history when one is — same gesture, contextually correct target. The swipe-up hint label and AppBar tooltip both reflect which one you're about to get.
- Data model: `CalculationSheet` gained `description`; `CalculationHistoryEntry` gained nullable `sheetId`. DB schema bumped to v3 with a migration that backfills both on existing installs (`ALTER TABLE ... ADD COLUMN`) — no data loss, no manual steps needed on upgrade. Deleting a sheet now also deletes its own history in the same batch, so it's never orphaned.

### Round 4 fixes
- **Dark/light contrast — actual root cause fixed** (`lib/theme/app_theme.dart`): the app's global `textTheme` was built via `GoogleFonts.interTextTheme()` with **no base argument**, which silently defaults to a fixed, light-mode/near-black baseline regardless of the app's real brightness. Any `Text` widget that didn't explicitly set its own color — dialog titles, drawer headers, list content, etc. — was rendering near-black text even in dark mode. Round 2's fixes patched a few specific widgets but missed this systemic cause. Fixed by building the base `ThemeData` from the `ColorScheme` first (which gives Flutter's own correctly brightness-aware text colors) and layering `GoogleFonts` on top of *that*, so it only changes font family/weight and keeps the color it's given. Also added explicit `dialogTheme` and `listTileTheme` overrides so dialogs and list content are correct by default too.
- **APK size**: removed the unused `cupertino_icons` dependency; confirmed `minifyEnabled`/`shrinkResources` are on for release builds; and the recommended build command is now `flutter build apk --release --split-per-abi`, which typically roughly halves download size by not bundling every CPU architecture into one file. See "APK size" under step 3 below for details — no app behavior changed, this is purely a build-configuration improvement.

### Round 3 fixes
- **Calculation engine rewritten from scratch** (`lib/services/expression_evaluator.dart`): replaced the `math_expressions`-based evaluator with a hand-written, dependency-free recursive-descent parser. The old library had no defined behavior for `%` at all (it simply errored), and gave no guarantee its `log`/`ln` matched calculator convention — so scientific results could be silently wrong even without erroring. The new evaluator:
  - Implements `%` with standard calculator semantics: `A + B%` / `A - B%` takes B% *of A* (`100+10% = 110`), while `A × B%` / `A ÷ B%` treats it as a literal `B/100` (`50×10% = 5`); a bare `B%` is `B/100`.
  - Uses `log` = base-10, `ln` = natural log (previously unverified/possibly swapped).
  - Correctly handles operator precedence including the classic `-2^2 = -4` vs. `(-2)^2 = 4` distinction that matches real scientific calculators.
  - Supports implicit multiplication (`2π`, `2(3+4)`, `2sin(30)`) like real calculator apps.
  - Guards `tan()` near its undefined asymptotes (90°, 270°, ...) instead of returning a meaningless huge number.
  - Verified against a 20-case test battery (basic arithmetic, all percent variants, power/precedence edge cases, all scientific functions, implicit multiplication, division-by-zero, incomplete-expression handling) before shipping.
  - Also removes the `math_expressions` package dependency entirely — smaller, faster build.
- **Keypad resized for better breathing room**: display/grid flex ratio changed from ~29/71 to ~43/57 in Standard mode (Scientific mode keeps a bit more grid room — ~29/71 — since it has two extra rows to fit), matching standard mobile calculator display-to-keypad proportions. Button padding and font size were tightened slightly to keep the now-smaller keys looking clean rather than cramped.

### Round 2 fixes
- **Exit a loaded Sheet**: the active-sheet chip on the display is now closable (×) — tapping it calls `CalculatorProvider.exitActiveSheet()`, detaching from the sheet without clearing your current expression, so you can keep calculating in plain (History-logged) mode.
- **Dark-mode contrast bug fixed**: several widgets (`_SheetTile`, `_HistoryTile`, the active-sheet `Chip`) previously left text color unset and relied on an ambient default, which read poorly against custom `secondaryContainer`/`surfaceContainerLow` fills in dark mode. All of these now use explicit `onSecondaryContainer` / `onSurface` colors that are correct in both themes.
- **Sheet-title bug fixed**: the "Save as new sheet" dialog's pre-filled suggested name (e.g. "Sheet 1") is now selected on open, so typing replaces it instead of appending — this previously produced titles like "Sheet 1sheet 1".
- **Clearer swipe-up-for-History affordance**: the old lone up-arrow icon is replaced by a standard drag-handle pill (the same shape used by bottom sheets) that morphs into an explicit "History" label + icon as you drag, in `_HistoryPeekHandle` (`lib/screens/calculator_screen.dart`).
- **Code cleanup / performance**: extracted the duplicated grabber-bar UI into `lib/widgets/drawer_grabber.dart`; replaced broad `context.watch<CalculatorProvider>()` subscriptions in the button grid and main screen with scoped `context.select`/`context.read`, so keystrokes no longer force the AppBar, Scientific toggle, and all ~25 buttons to rebuild on every tap.

---

## 1. Prerequisites

Install these once on your machine:

1. **Flutter SDK** (3.24+) — https://docs.flutter.dev/get-started/install
2. **Android SDK & platform tools** — installed automatically alongside
   Android Studio, or standalone via `sdkmanager`
3. **VS Code** with the **Flutter** and **Dart** extensions
4. A device to run on: a physical Android phone (USB debugging enabled) or
   an emulator created via Android Studio's Virtual Device Manager

Verify everything is wired up correctly:

```bash
flutter doctor
```

Resolve any `[✗]` items it reports (usually accepting Android licenses via
`flutter doctor --android-licenses`) before continuing.

---

## 2. Open and run the project in VS Code

```bash
# 1. Unzip the project, then enter it
cd calcbook

# 2. Let Flutter fill in any machine-specific scaffold files
#    (local.properties, gradle-wrapper.jar, etc.) it needs for your SDK paths
flutter create .

# 3. Fetch dependencies
flutter pub get

# 4. Open in VS Code
code .
```

Then in VS Code:

1. Open the **Command Palette** → `Flutter: Select Device` → pick your
   emulator or connected phone.
2. Press **F5** (or `Run > Start Debugging`) — the app launches in debug
   mode with hot reload (`r`) / hot restart (`R`) available in the terminal.

---

## 3. Generate a release `.apk`

From the project root, the **recommended** command (see "APK size" below
for why):

```bash
flutter build apk --release --split-per-abi
```

This produces three smaller, architecture-specific APKs instead of one
large universal one:

```
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk    (most modern phones — try this first)
build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk  (older 32-bit phones)
build/app/outputs/flutter-apk/app-x86_64-release.apk       (rare — x86 devices/emulators)
```

Each one is fully self-contained and installs exactly like any other
APK — copy the matching file to your phone (`arm64-v8a` covers the vast
majority of phones from the last ~8 years) and open it (enable **Install
from unknown sources** for your file manager/browser if prompted).

If you'd rather have a single universal file that installs on any device
(larger, but simpler to share):

```bash
flutter build apk --release
```

Output:
```
build/app/outputs/flutter-apk/app-release.apk
```

### APK size

A few things keep this build lean without touching any feature or
behavior:
- **`--split-per-abi`** (above) is the single biggest win — a universal
  APK bundles native code for every CPU architecture; splitting means
  each device only downloads the one it actually needs, typically
  roughly halving the file size.
- **`minifyEnabled true` / `shrinkResources true`** are already set in
  `android/app/build.gradle`, so R8 strips unused code and resources
  from every release build automatically.
- **No unused dependencies** — `cupertino_icons` was removed since the
  app only uses Material icons, and the earlier `math_expressions`
  package was already dropped when the calculation engine was rewritten.
- Flutter's release builds automatically tree-shake icon fonts (unused
  Material icon glyphs are stripped) and strip debug symbols — no
  action needed, both are on by default for `--release`.

If you want to go further for a public release, two optional flags trim
a bit more at the cost of build complexity (you'd need to keep the
generated `symbols/` folder to de-obfuscate any future crash reports):
```bash
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=build/symbols
```

### Optional: build an `.aab` for Play Store upload

```bash
flutter build appbundle --release
```

---

## 4. Sign with your own release key (recommended before distributing)

By default, `release` builds use the Flutter debug key so
`flutter build apk` works immediately with zero setup. Before distributing
CalcBook to real users, switch to your own key:

```bash
keytool -genkey -v -keystore ~/calcbook-release.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias calcbook
```

Then:

1. Copy `android/key.properties.example` → `android/key.properties`
2. Fill in `storePassword`, `keyPassword`, `keyAlias`, and the absolute
   `storeFile` path to the `.jks` you just generated
3. Re-run `flutter build apk --release` — the build script automatically
   detects `key.properties` and signs with it instead of the debug key

`android/key.properties` and any `.jks`/`.keystore` files are already
excluded via `.gitignore` — never commit your real signing key.

---

## 5. Build the APK automatically via GitHub Actions (no local setup)

A ready-to-use workflow is included at
`.github/workflows/build_apk.yml`. Push this project to a GitHub repo and
it will automatically:

1. Set up Java 17 + Flutter
2. Run `flutter pub get`, `flutter analyze`, `flutter test`
3. Run `flutter build apk --release`
4. Upload `app-release.apk` as a downloadable workflow artifact

You can also trigger it manually from the **Actions** tab
(`workflow_dispatch`) without pushing new code.

---

## 6. Run tests

```bash
flutter test
```

`test/widget_test.dart` includes a smoke test (app launches, key buttons
render) and a basic calculation test (`7 + 3 = 10`).

---

## Notes on scope

- **State management:** `provider` (lightweight `ChangeNotifier`-based
  MVVM), matching the spec's request for a clean, single-responsibility
  ViewModel layer.
- **Persistence:** `sqflite`, the most direct Room equivalent in Flutter —
  same relational, SQL-backed model, same single-table design
  (`id`, `title`, `expression`, `displayOrder`).
- **Math evaluation:** `math_expressions`, a pure-Dart parser/evaluator
  analogous to exp4j; `ExpressionEvaluator` adds degree-based trig
  handling and calculator-friendly formatting on top of it.
- **Design:** Material 3 (`useMaterial3: true`) with a custom seeded color
  scheme, tonal button roles (numbers/operators/functions/accent),
  56dp+ square touch targets, and `google_fonts` for a monospace display
  face on the expression readout.
