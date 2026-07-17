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

From the project root:

```bash
flutter build apk --release
```

The signed (debug-key by default — see signing note below) APK is written to:

```
build/app/outputs/flutter-apk/app-release.apk
```

Copy that file to your Android device and open it (enable **Install from
unknown sources** for your file manager/browser if prompted) to install.

### Optional: build a smaller, split APK per architecture

```bash
flutter build apk --release --split-per-abi
```

Produces smaller per-ABI APKs in the same output folder — useful for
distributing outside the Play Store to save download size.

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
