# CalcBook 🧮

CalcBook is a modern, lightweight Android calculator app engineered with Jetpack Compose and Room DB. Beyond standard and scientific arithmetic, CalcBook introduces **Calculation Sheets**—a persistent workspace utility that allows users to bookmark active calculation threads, name them, and resume them at any time.

## ✨ Features

- **Dual Modes:** Seamlessly toggle between a streamlined Standard layout and an advanced Scientific panel ($\sin$, $\cos$, $\tan$, $\log$, $\ln$, exponents, and parentheses).
- **Calculation Sheets:** Save your active calculation state as an independent workspace (e.g., separating project budgets from daily expense tracking).
- **Workspace Manager:** An intuitive, industry-standard management sheet to rename, delete, and reorder your saved sessions.
- **Modern UI/UX:** Built strictly following Material 3 design guidelines with a focus on tactile touch-targets and fluid animations.

## 🏗️ Architecture & Tech Stack

The app is built on clean, modern Android architecture patterns designed for maximum performance and low memory overhead:

- **Presentation:** Jetpack Compose (Declarative UI) with MVVM pattern using Architecture Components (`ViewModel`, `StateFlow`).
- **Persistence:** Room Database over SQLite for efficient local storage of calculation states.
- **Math Engine:** `exp4j` for lightweight, deterministic mathematical expression evaluation and tokenization.
- **Asynchrony:** Kotlin Coroutines for non-blocking database operations.

## 🚀 Getting Started

### Prerequisites
- Android Studio Ladybug (or newer) / Google Antigravity IDE
- JDK 17+
- Android SDK 24+ (Android 7.0 Nougat or higher)

### Installation & Build

1. Clone the repository:
   ```bash
   git clone [https://github.com/yourusername/CalcBook.git](https://github.com/yourusername/CalcBook.git)
