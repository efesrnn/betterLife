# Better Life 🌱
### Habit Tracking & Social Competition Platform

> A cross-platform mobile application that helps users build lasting habits through intelligent tracking, streak-based motivation, and competitive social features — powered by Flutter, Supabase, and Google Gemini AI.

---

## 📱 Overview

Better Life is a full-stack mobile application built with Flutter and Supabase that transforms habit building into an engaging, competitive experience. Users can track multiple habits simultaneously, earn streak bonuses, compete with friends on leaderboards, and receive AI-powered validation for their logged activities.

The application is designed from the ground up to be **language-agnostic** — supporting multiple locales without any logic changes to the backend.

---

## ✨ Features

### 🎯 Habit Tracking
- Create and manage multiple habits simultaneously with independent tracking
- Flexible scoring engine that rewards consistency and effort
- Daily, weekly, and custom frequency support for diverse habit types

### 🔥 Streak System
- Per-habit streak tracking — each habit maintains its own independent streak counter
- **Combo streak bonus system** that rewards users who complete multiple habits consecutively
- Streak recovery and grace period logic to prevent motivation loss

### 🤖 AI-Powered Validation
- Integrated with the **Google Gemini API** to validate habit completions and logged activities
- Dynamic validation prompts ensure that user-submitted evidence matches the habit goal
- Prevents dishonest logging while keeping the experience frictionless for genuine completions

### 🏆 Social Competition (HabitArena)
- Compete with friends and other users on habit-specific leaderboards
- Challenge system to pit users head-to-head on shared habit goals
- Score-based ranking updated in real time via Supabase subscriptions

### 🌍 Full Internationalization
- Cross-language semantic search powered by **pgvector** with multi-locale embeddings
- All UI strings are rendered client-side using **Flutter's easy_localization** package
- Supabase Edge Functions return only machine-readable **i18n keys** — keeping the backend fully language-agnostic and independent of any locale

---

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Mobile (Frontend) | Flutter / Dart |
| Backend & Auth | Supabase (PostgreSQL, Auth, Storage) |
| Edge Functions | Supabase Edge Functions (Deno / TypeScript) |
| AI Validation | Google Gemini API |
| Semantic Search | pgvector (multi-locale embeddings) |
| Internationalization | easy_localization |
| Real-time | Supabase Realtime Subscriptions |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────┐
│               Flutter Client                │
│  ┌──────────────┐   ┌─────────────────────┐ │
│  │ easy_localize│   │  Supabase Flutter   │ │
│  │  (i18n keys  │   │       SDK           │ │
│  │  → UI text)  │   └─────────────────────┘ │
└──────────────────────────────┬──────────────┘
                               │
┌──────────────────────────────▼──────────────┐
│              Supabase Backend               │
│  ┌─────────────┐  ┌────────┐  ┌──────────┐ │
│  │ Edge Funcs  │  │  Auth  │  │ Realtime │ │
│  │(returns i18n│  │        │  │  (scores,│ │
│  │    keys)    │  └────────┘  │ streaks) │ │
│  └──────┬──────┘              └──────────┘ │
│         │                                  │
│  ┌──────▼──────────────────────────┐       │
│  │   PostgreSQL + pgvector         │       │
│  │  (habits, scores, embeddings)   │       │
│  └─────────────────────────────────┘       │
└──────────────────────────────┬──────────────┘
                               │
┌──────────────────────────────▼──────────────┐
│           Google Gemini API                 │
│       (Activity Validation Engine)          │
└─────────────────────────────────────────────┘
```

### Key Architectural Decisions

- **Language-agnostic backend:** Edge Functions never return human-readable strings. All user-facing text is resolved on the client using i18n key maps — making the entire backend locale-independent and easy to extend to new languages.
- **Independent streak tracking:** Each habit maintains its own streak state, decoupled from other habits. This allows granular recovery logic and per-habit analytics.
- **Combo bonus layer:** A separate scoring layer sits on top of individual habit scores to reward cross-habit consistency without polluting per-habit data.

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK `>=3.0.0`
- Dart SDK `>=3.0.0`
- A [Supabase](https://supabase.com) project
- A [Google Gemini API](https://ai.google.dev) key
- Supabase CLI (for deploying Edge Functions)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/efesrnn/better-life.git
   cd better-life
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure environment**

   Create a `.env` file in the project root:
   ```env
   SUPABASE_URL=your_supabase_project_url
   SUPABASE_ANON_KEY=your_supabase_anon_key
   GEMINI_API_KEY=your_gemini_api_key
   ```

4. **Set up the database**

   Run the SQL migrations located in `/supabase/migrations` against your Supabase project, or use the Supabase CLI:
   ```bash
   supabase db push
   ```

5. **Deploy Edge Functions**
   ```bash
   supabase functions deploy
   ```

6. **Run the app**
   ```bash
   flutter run
   ```

---

## 📂 Project Structure

```
better-life/
├── lib/
│   ├── core/
│   │   ├── scoring/          # Scoring engine & combo bonus logic
│   │   ├── streak/           # Per-habit streak tracking
│   │   └── i18n/             # Localization key maps
│   ├── features/
│   │   ├── habits/           # Habit CRUD & tracking screens
│   │   ├── arena/            # Social competition & leaderboards
│   │   ├── validation/       # Gemini API integration
│   │   └── auth/             # Supabase Auth flows
│   └── main.dart
├── supabase/
│   ├── functions/            # Edge Functions (Deno/TypeScript)
│   └── migrations/           # PostgreSQL schema & pgvector setup
└── assets/
    └── i18n/                 # Locale JSON files (en, tr, ...)
```

---

## 🌐 Internationalization

Better Life uses a strict separation between backend logic and language rendering:

1. **Edge Functions** process all business logic and return structured responses with **i18n keys** (e.g., `habit.streak.broken`, `validation.failed.evidence_missing`).
2. **Flutter client** maps these keys to locale-specific strings via `easy_localization`.
3. **Semantic search** across habits and activities uses `pgvector` embeddings generated for each supported locale, enabling accurate cross-language search results.

To add a new language, only a new JSON file under `assets/i18n/` is required — no backend changes needed.

---

## 🤝 Contributing

Contributions are welcome! Please open an issue first to discuss what you'd like to change.

1. Fork the repository
2. Create your feature branch: `git checkout -b feature/your-feature`
3. Commit your changes: `git commit -m 'Add your feature'`
4. Push to the branch: `git push origin feature/your-feature`
5. Open a Pull Request

---

## 👤 Authors

**Efe Serin & Alp Koçak**
