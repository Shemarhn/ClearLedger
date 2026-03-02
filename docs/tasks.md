# ClearLedger — Step-by-Step Master Task List
**Course:** COMP3901 — Capstone Project | **Supervisor:** Dr. Ricardo Anderson
**Presentation Deadline:** ~8 weeks | **Team Meetings:** Every Friday
**Version:** 3.0

---

## Ground Rules

- Every task has a checkbox. Check it off and push this file when done.
- Team assignments are suggestions only. Reassign freely at every Friday meeting based on who is available and what is blocked.
- Nobody stays blocked more than 2 hours without messaging the group.
- All work goes through pull requests into `dev`. Nothing pushes directly to `main` or `dev`.
- No new features after the end of Week 5. Ideas go into `docs/future_features.md`.

---

## Team

| Name | Student ID | Email | Default Starting Role |
|---|---|---|---|
| Shemar Marks | 620149911 | marks.shemarhn@gmail.com | LLM Pipeline |
| Davi-Ann Mills | 620154921 | daviannmills03@gmail.com | LLM Pipeline |
| Shaedane (Shae) White | 620165572 | wgary283@gmail.com | Backend + Frontend |
| Reynaldo Allison | 620146955 | Reynaldostudent123@gmail.com | Backend + Frontend |

---

## What ClearLedger Does (Read Once, Understand Fully)

ClearLedger lets users log cash transactions in two ways: by photographing a receipt, or by typing a natural language description of a purchase. Both inputs are processed by an LLM that extracts the merchant, amount, date, and category automatically. The user then reviews and confirms the result on screen before it is saved. Bank transactions are pulled automatically via Plaid. All transactions — cash and bank — appear in one unified ledger with budgets, dashboards, and exportable reports.

---

## Recommended Tech Stack

Research was done on all options before writing this list. Here is what is recommended and why each decision was made.

### LLM — Team Must Vote on This at the Week 1 Friday Meeting

The team has budget flexibility, so this is a real decision. The models mentioned in the brief (GPT 5.3 and Gemini 3.1) do not exist at the time of writing. The correct current equivalents are below.

| Option | Model | Cost | Notes |
|---|---|---|---|
| **Recommended (free)** | Google Gemini 2.0 Flash via Google AI Studio | Free — 15 req/min, 1,500 req/day | Sufficient for all development and the demo. Most practical choice. |
| **Recommended (paid, best value)** | Google Gemini 2.5 Flash | ~$0.075 per 1M tokens | ~40× cheaper than Claude or GPT. Near top accuracy on receipt extraction. |
| **Best accuracy (paid)** | Claude Sonnet 4.6 (Anthropic) | ~$3 per 1M input tokens | Top-ranked on structured image table extraction benchmarks. ~$10–15 covers the entire project. |
| **Solid alternative (paid)** | GPT-4.1 (OpenAI) | ~$2 per 1M input tokens | Widely documented. Good receipt accuracy. |
| **Free alternative** | Grok (xAI free tier) | Free | Less tested on receipt parsing. Higher risk. Not recommended. |

**Decision path:** Start with the free Gemini 2.0 Flash tier. If rate limits are hit or accuracy is unsatisfactory during Week 3 testing, upgrade to Gemini 2.5 Flash or Claude Sonnet 4.6 at that point.

### Full Stack

| Layer | Tool | Reason |
|---|---|---|
| Frontend | Flutter (Dart) | As proposed. Correct choice for Android + Windows from one codebase. |
| State Management | Riverpod 2.0 | Modern successor to Provider. Compile-time safety, cleaner code. |
| Navigation | go_router | Handles auth redirect guards and named routes cleanly. |
| Database + Auth + Storage | Supabase | PostgreSQL + Auth + File Storage + Row Level Security in one platform. Replaces Firebase + PostgreSQL + Express.js from the proposal — all of that is what Supabase already is. SQL is better for relational financial data than Firestore NoSQL. |
| Custom API | FastAPI (Python) on Railway | Handles LLM calls, Plaid integration, scheduled syncs, and exports. Python is the standard for LLM integrations. Railway deploys from GitHub in under 5 minutes — no server setup. |
| Bank Integration | Plaid Sandbox (demo) + CSV import (real-world fallback) | Plaid has no live connections to Jamaican banks (NCB, Scotiabank JA). Sandbox works for the demo. CSV import is the honest real-world solution for Jamaican users. |
| Push Notifications | Firebase Cloud Messaging | Supabase does not handle mobile push notifications natively. FCM is still used for this one function. |
| Design | Figma | As proposed. |
| Version Control | GitHub | Already initialized. |

---

## 8-Week Timeline

| Week | Friday Checkpoint — Must Be True by End of Day Friday |
|---|---|
| Week 1 | Repo structure set up. All accounts and API keys obtained. Every member's environment is working. LLM decision made. |
| Week 2 | All Figma screens signed off. Supabase tables, RLS, storage bucket, and auto-profile trigger live. FastAPI skeleton deployed on Railway. |
| Week 3 | LLM pipeline working for both receipt image and text input. Auth screens in Flutter done and connected to Supabase. |
| Week 4 | All FastAPI endpoints complete. Plaid sandbox link working. CSV import working. Push notification plumbing set up. |
| Week 5 | Dashboard, Receipt Scan flow, and Text Input flow working end-to-end on a real Android device. |
| Week 6 | All Flutter screens complete. Budget alerts firing. App builds to release APK without errors. |
| Week 7 | All 8 integration test journeys pass. All P1 and P2 bugs fixed. Demo data loaded. App on production backend. |
| Week 8 | Demo rehearsed twice. All docs complete. Repo cleaned. Ready to present. |

---

---

# PHASE 0 — Repository and Environment Setup
**Suggested Owner:** Reynaldo for repo, Shae for accounts, all members for local setup
**Deadline:** End of Week 1

---

### 0.1 — Branch Structure
**Suggested Owner: Reynaldo**

- [ ] Confirm the existing `main` branch is clean and has the initial Flutter project committed
- [ ] Create a `dev` branch from `main` — this is the integration branch all PRs merge into
- [ ] Create a `feature/llm-pipeline` branch from `dev`
- [ ] Create a `feature/backend` branch from `dev`
- [ ] Create a `feature/frontend` branch from `dev`
- [ ] In GitHub Settings → Branches, set `dev` as the default branch so the repo opens to `dev`
- [ ] In GitHub Settings → Branches, add a branch protection rule to `main` requiring at least one PR review before any merge
- [ ] In GitHub Settings → Branches, add the same protection to `dev` — no direct pushes, only PRs
- [ ] Create a `.gitignore` file in the repo root covering: Flutter build folders, Python `venv/` and `__pycache__/`, all `.env` files, `google-services.json`, and `*.keystore` files
- [ ] Create a `.env.example` file in the repo root with the following keys present but values left blank: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_JWT_SECRET`, `LLM_API_KEY`, `PLAID_CLIENT_ID`, `PLAID_SECRET`, `PLAID_ENV`, `FCM_SERVER_KEY`, `ENCRYPTION_KEY`
- [ ] Commit `.gitignore` and `.env.example` to `dev` and push

---

### 0.2 — Accounts and API Keys
**Suggested Owner: Shae — share credentials through a private locked Google Doc, never through chat or GitHub**

- [ ] Create a Supabase project at supabase.com — name it `clearledger`
- [ ] From the Supabase project settings, collect and securely share: Project URL, anon key, service role key, and JWT Secret (all four are needed)
- [ ] Based on the team's LLM vote, obtain the API key for the chosen model:
  - For Gemini (free or paid): go to aistudio.google.com and generate a key
  - For Claude: go to console.anthropic.com and generate a key
  - For GPT-4.1: go to platform.openai.com and generate a key
- [ ] Immediately test the API key by sending a basic text prompt and confirming a response comes back before continuing
- [ ] Create a Plaid developer account at dashboard.plaid.com — select Sandbox when prompted — collect the client ID and secret
- [ ] Create a Firebase project at console.firebase.google.com — enable Cloud Messaging only, no other Firebase services are needed
- [ ] In the Firebase project, register an Android app using the Flutter package name from `android/app/build.gradle`
- [ ] Download `google-services.json` from Firebase and place it in `android/app/` inside the Flutter project
- [ ] Confirm `google-services.json` is listed in `.gitignore` before committing anything — this file must never be committed
- [ ] Add all credentials to your own local `.env` file following the `.env.example` format

---

### 0.3 — Local Development Setup
**Every member does this on their own machine**

- [ ] Install Flutter SDK on the stable channel — run `flutter doctor` and resolve every issue shown before proceeding
- [ ] Install Android Studio with the Android SDK, minimum API level 30
- [ ] Set up an Android emulator (Pixel 5, API 33 is recommended) OR connect a physical Android device with USB debugging enabled
- [ ] Run `flutter devices` and confirm at least one device appears
- [ ] Install Python 3.11 or higher — verify with `python3 --version`
- [ ] Install VS Code with the following extensions: Flutter, Dart, Python, Pylance, GitLens
- [ ] Clone the repository and checkout the `dev` branch
- [ ] Run `flutter pub get` inside the project root
- [ ] Run `flutter run` and confirm the app launches on your device without crashing
- [ ] Create your own local `.env` file based on `.env.example` and fill in the values shared by Shae

---

### 0.4 — Flutter Project Structure
**Suggested Owner: Reynaldo**

- [ ] Reorganize the `lib/` folder to match the following structure — create any missing subfolders with a placeholder `.gitkeep` file so they are tracked by Git:
  - `lib/core/` — for `constants.dart`, `supabase_client.dart`, `router.dart`
  - `lib/models/` — for all data classes
  - `lib/providers/` — for all Riverpod providers
  - `lib/screens/` — with one subfolder per screen
  - `lib/services/` — for `api_service.dart` and `notification_service.dart`
  - `lib/widgets/` — for reusable components used across multiple screens
- [ ] Create a `backend/` folder in the repo root for the FastAPI project
- [ ] Create a `docs/` folder in the repo root for schema files, test logs, and reports
- [ ] Commit the folder structure to `dev` and push so all members have the same layout

---

### 0.5 — Flutter Dependencies
**Suggested Owner: Reynaldo**

- [ ] Open `pubspec.yaml` and add the following packages under `dependencies`:
  - `supabase_flutter` version 2.3.0 or higher — Supabase client for database, auth, and storage
  - `flutter_riverpod` version 2.4.0 or higher — state management
  - `go_router` version 13.0.0 or higher — navigation with auth guards
  - `camera` version 0.10.0 or higher — live camera preview for receipt scanning
  - `image_picker` version 1.0.0 or higher — gallery upload fallback
  - `firebase_core` version 2.24.0 or higher — Firebase initialization
  - `firebase_messaging` version 14.7.0 or higher — push notifications
  - `flutter_local_notifications` version 16.3.0 or higher — in-app notification display
  - `fl_chart` version 0.66.0 or higher — charts for dashboard and reports
  - `pdf` version 3.10.0 or higher — PDF generation for exports
  - `csv` version 6.0.0 or higher — CSV parsing for bank statement imports
  - `share_plus` version 7.2.0 or higher — sharing exported files
  - `open_filex` version 4.3.4 or higher — opening exported files on device
  - `flutter_secure_storage` version 9.0.0 or higher — secure local data storage
  - `local_auth` version 2.1.8 or higher — biometric and PIN authentication
  - `intl` version 0.19.0 or higher — currency and date formatting
  - `shared_preferences` version 2.2.2 or higher — storing simple preferences like onboarding state
  - `http` version 1.2.0 or higher — HTTP calls to the FastAPI backend
- [ ] Run `flutter pub get` and resolve any version conflicts before continuing
- [ ] Commit `pubspec.yaml` and `pubspec.lock` to `dev`

---

### 0.6 — LLM Decision (Decided at the Week 1 Friday Meeting)
**All members**

- [ ] At the Friday meeting, each member reads the LLM comparison table at the top of this document
- [ ] Team votes on which model to use — consider the free Gemini route as default unless the team has budget allocated
- [ ] Record the decision in a new file `docs/technical_decisions.md` with the model chosen and the reason
- [ ] Commit `docs/technical_decisions.md` to `dev`

---

---

# PHASE 1 — Figma UI/UX Design
**Suggested Owner:** Shae (lead), Reynaldo (reviewer) — Shemar and Davi-Ann get view access
**Deadline:** End of Week 2 — no Flutter screen code starts before this phase is signed off

---

### 1.1 — Design System
**Suggested Owner: Shae**

- [ ] Create a new Figma project named `ClearLedger UI`
- [ ] Share the project: edit access for Reynaldo, view access for Shemar and Davi-Ann
- [ ] Define a color palette including: primary, secondary accent, error red, success green, warning amber, neutral grays, background, and surface — use a deep teal or navy as the primary (finance apps read as trustworthy with cool colors)
- [ ] Define a typography scale using Inter or Nunito — define sizes and weights for: Display, H1, H2, H3, Body Large, Body, Caption, and Label
- [ ] Build reusable Figma components for the following — each component must show all relevant states:
  - [ ] Primary button (default, hover, disabled)
  - [ ] Secondary button (default, hover, disabled)
  - [ ] Text input field (default, focused, error)
  - [ ] Card (small and large variants)
  - [ ] Category chip or badge with icon
  - [ ] Bottom navigation bar with 4 tabs: Home, Transactions, Budget, Settings
  - [ ] Top app bar
  - [ ] Loading skeleton that mimics content layout
  - [ ] Empty state layout with icon and message text
  - [ ] Transaction list item row (category icon, merchant name, date, amount, source badge)
  - [ ] Progress bar for budget display (green, orange, and red states)

---

### 1.2 — Authentication Screens
**Suggested Owner: Shae — each screen needs default, loading, and error states**

- [ ] Design the Splash screen — logo centered, subtle loading animation
- [ ] Design the Onboarding screen — 3 swipeable slides:
  - Slide 1: explains receipt photo scanning
  - Slide 2: explains the text description input with an example phrase shown on screen
  - Slide 3: explains automatic bank account syncing
  - Skip button in the top right on all slides, Next on slides 1–2, Get Started on slide 3
- [ ] Design the Sign Up screen — fields for full name, email, password, confirm password, inline validation errors, and a Sign Up button
- [ ] Design the Login screen — fields for email and password, a biometric authentication button, a Forgot Password link, and a Log In button

---

### 1.3 — Main App Screens
**Suggested Owner: Shae — each screen needs default, loading, and empty/error states**

- [ ] Design the Dashboard / Home screen:
  - Monthly summary card with total spent, total budget, and a colored progress bar
  - Category donut chart for the current month
  - Recent transactions list (5 items)
  - Floating action button that expands to show 3 options: Scan Receipt, Type Transaction, Link Bank
- [ ] Design the Transaction List screen — search bar, category and date range filters, paginated list with source badges, empty state
- [ ] Design the Transaction Detail screen — all transaction fields, receipt image thumbnail, original text input display, edit and delete controls
- [ ] Design the Add Transaction (manual) screen — fallback form for manual entry
- [ ] Design the Receipt Scan screen — live camera viewfinder, capture button, gallery upload button
- [ ] Design the Text Input screen — large multiline text field, example placeholder text, character counter, Process Transaction button
- [ ] Design the Confirmation screen (shared by receipt scan and text input flows):
  - Receipt thumbnail or text icon depending on source
  - All extracted fields as editable inputs
  - Amber highlight and "Please fill in" label for null fields
  - Confidence badge (green above 80%, yellow 50–80%, red below 50%)
  - Save Transaction button and Discard button
- [ ] Design the Bank Link screen — Plaid OAuth web view placeholder, success state, and a clearly visible CSV Import fallback section
- [ ] Design the Budget Overview screen — category cards with animated progress bars, over-budget badge, empty state
- [ ] Design the Create and Edit Budget screen — category dropdown, amount field, period toggle, date range pickers, delete button for edit mode
- [ ] Design the Reports screen — date range presets, summary stat cards, month-over-month bar chart, category breakdown table, PDF and CSV export buttons
- [ ] Design the Settings screen — profile section, linked accounts section, CSV import button, notifications toggle, biometric toggle, sync button, logout button

---

### 1.4 — Design Review and Sign-Off
**Reynaldo reviews, Shae revises, both sign off**

- [ ] Reynaldo reviews every screen in Figma and leaves written comments for anything missing, inconsistent, or unclear
- [ ] Shae actions every comment from Reynaldo and updates the designs
- [ ] Both Shae and Reynaldo write a written sign-off in the team group chat confirming designs are approved
- [ ] Shemar and Davi-Ann are notified that designs are available to view — they should familiarize themselves with the confirmation screen since their pipeline feeds directly into it

---

---

# PHASE 2 — Supabase Database and Security
**Suggested Owner:** Reynaldo for tables, Shae for security and triggers
**Deadline:** End of Week 2 | Branch: `feature/backend`

---

### 2.1 — Create Database Tables
**Suggested Owner: Reynaldo**

- [ ] Open the Supabase dashboard, navigate to the SQL Editor
- [ ] Create the `profiles` table with the following columns: UUID primary key referencing `auth.users` with cascade delete, `name` text not null, `email` text not null, `fcm_token` text nullable, `biometric_enabled` boolean defaulting to false, `created_at` timestamp with timezone defaulting to now
- [ ] Create the `accounts` table with the following columns: UUID primary key, `user_id` UUID referencing `profiles` with cascade delete not null, `account_name` text not null, `account_type` text constrained to the values bank / cash / wallet, `plaid_access_token` text nullable, `plaid_item_id` text nullable, `plaid_account_id` text nullable, `balance` decimal defaulting to 0, `currency` text defaulting to JMD, `created_at` timestamp
- [ ] Create the `transactions` table with the following columns: UUID primary key, `user_id` UUID referencing `profiles` cascade delete not null, `account_id` UUID referencing `accounts` nullable, `amount` decimal not null, `currency` text defaulting to JMD, `category` text not null, `description` text nullable, `merchant_name` text nullable, `transaction_date` timestamp not null, `source` text constrained to the values ocr / text-input / bank-sync / manual, `receipt_image_path` text nullable (Supabase Storage path), `raw_llm_input` text nullable (original text from text input flow), `gemini_confidence` decimal nullable (0.0–1.0), `plaid_transaction_id` text unique nullable (for deduplication), `created_at` timestamp
- [ ] Create the `budgets` table with the following columns: UUID primary key, `user_id` UUID referencing `profiles` cascade delete not null, `category` text not null, `amount` decimal not null constrained to greater than zero, `period` text constrained to weekly / monthly, `start_date` date not null, `end_date` date not null constrained to be after `start_date`, `alert_sent_80` boolean defaulting to false, `alert_sent_100` boolean defaulting to false, `created_at` timestamp
- [ ] Create indexes on: `transactions.user_id`, `transactions.transaction_date`, `transactions.category`, `budgets.user_id`
- [ ] Verify all four tables appear in the Supabase Table Editor
- [ ] Save the full SQL script to `docs/database_schema.sql` and commit it to the `feature/backend` branch

---

### 2.2 — Row Level Security Policies
**Suggested Owner: Shae**

- [ ] In the Supabase SQL Editor, enable Row Level Security on all four tables: `profiles`, `accounts`, `transactions`, `budgets`
- [ ] Create a policy on `profiles` allowing all operations (select, insert, update, delete) where `auth.uid()` equals the row's `id`
- [ ] Create a policy on `accounts` allowing all operations where `auth.uid()` equals `user_id`
- [ ] Create a policy on `transactions` allowing all operations where `auth.uid()` equals `user_id`
- [ ] Create a policy on `budgets` allowing all operations where `auth.uid()` equals `user_id`
- [ ] Test the policies: create two test user accounts in Supabase Auth, insert one transaction under each user, and confirm that querying the table as one user does not return the other user's row
- [ ] Save the policy SQL to `docs/supabase_policies.sql` and commit it

---

### 2.3 — Receipt Image Storage Bucket
**Suggested Owner: Shae**

- [ ] In Supabase dashboard, navigate to Storage and create a new bucket named `receipts`
- [ ] Set the bucket visibility to Private
- [ ] In the SQL Editor, create a storage policy on `storage.objects` that allows all operations only when the first folder segment of the file path matches the authenticated user's ID — this means images are stored at the path `{user_id}/{filename}` and users cannot access each other's files
- [ ] Test the policy: upload a test image while authenticated as one test user, then attempt to access that file's URL while authenticated as a different test user and confirm access is denied

---

### 2.4 — Auto-Create Profile on Signup
**Suggested Owner: Shae**

- [ ] In the Supabase SQL Editor, create a Postgres function named `handle_new_user` that: fires as a trigger, inserts a new row into the `profiles` table using the new auth user's `id`, their name from `raw_user_meta_data`, and their `email`
- [ ] Create a trigger named `on_auth_user_created` on the `auth.users` table that fires after each insert and calls `handle_new_user`
- [ ] Test the trigger: sign up a completely new user through Supabase Auth, then check the `profiles` table and confirm a corresponding row was automatically created with the correct name and email
- [ ] Confirm the trigger still works correctly if a user signs up without providing a name — the function should fall back to a default value rather than throwing an error

---

---

# PHASE 3 — LLM Pipeline: Receipt Images and Text Descriptions
**Suggested Owner:** Shemar for service and FastAPI setup, Davi-Ann for testing and auth middleware
**Deadline:** End of Week 3 | Branch: `feature/llm-pipeline`

---

### 3.1 — Agree on Output Structure Before Writing Any Code
**All members of the LLM team**

- [ ] Agree on and document the exact JSON structure the LLM must return for every call — both receipt image and text input should return the same shape:
  - `merchant_name` — string or null
  - `amount` — number or null
  - `currency` — string defaulting to JMD
  - `date` — ISO 8601 date string or null
  - `category` — exactly one of: Groceries, Dining, Transport, Healthcare, Utilities, Entertainment, Shopping, Education, Other
  - `description` — one-sentence summary of the transaction
  - `confidence` — decimal between 0.0 and 1.0
  - `line_items` — array of objects with `name` and `price`, or null
- [ ] Record this agreed structure in `docs/technical_decisions.md` and commit it — both the backend team and the frontend team build to this spec

---

### 3.2 — FastAPI Project Setup
**Suggested Owner: Shemar**

- [ ] Navigate to the `backend/` folder in the repo
- [ ] Create a Python virtual environment inside `backend/` — name it `venv`
- [ ] Activate the virtual environment
- [ ] Install the following packages: `fastapi`, `uvicorn`, `python-dotenv`, `Pillow`, `python-multipart`, `supabase`, `PyJWT`, `reportlab`, `cryptography`, `apscheduler`, and the API client library for the chosen LLM (google-generativeai for Gemini, anthropic for Claude, openai for GPT)
- [ ] Run `pip freeze > requirements.txt` to save all dependencies
- [ ] Create the folder structure inside `backend/`: `middleware/`, `routers/`, `services/`
- [ ] Create `backend/main.py` with a FastAPI app instance and a single `/health` GET route that returns a status ok response
- [ ] Create `backend/.env` based on the `.env.example` and fill in all values — confirm this file is in `.gitignore`
- [ ] Run `uvicorn main:app --reload` inside `backend/` and confirm the health endpoint responds at `http://localhost:8000/health`

---

### 3.3 — Build the LLM Extraction Service
**Suggested Owner: Shemar**

- [ ] Create `backend/services/llm_service.py`
- [ ] Configure the LLM API client using the key from the environment variables
- [ ] Write the system prompt for receipt image processing — the prompt must instruct the model to: act as a financial data extractor for a Caribbean finance app, return only a valid JSON object with the agreed output structure and nothing else (no markdown, no explanation), default currency to JMD unless clearly shown otherwise, use the final grand total and not a subtotal if multiple totals appear, choose a category from the fixed list, return null for any field that cannot be determined, and set the confidence score based on how clearly legible the receipt is
- [ ] Implement the `parse_receipt_image(image_bytes)` function that: accepts raw image bytes, constructs the image and prompt together, sends them to the LLM API, strips any markdown code fences from the response if the model wraps the JSON in them, parses the response as JSON, and returns the result as a Python dictionary
- [ ] Write the system prompt for text description processing — the prompt must instruct the model to: extract the same structured data from a natural language sentence, default the date to today if no date is mentioned (today's date must be passed in dynamically), default currency to JMD, note that line items will almost always be null for text descriptions, and set confidence based on how specific and unambiguous the description is
- [ ] Implement the `parse_text_description(user_text, today_date)` function following the same pattern — accept text and today's date, send to the LLM, clean the response, parse, and return
- [ ] Add error handling to both functions: if the model returns text that cannot be parsed as valid JSON, raise a clear exception with a descriptive message
- [ ] Create a standalone test script at `backend/test_llm.py` that calls both functions directly with hardcoded inputs so the team can test the raw extraction before the HTTP layer is built

---

### 3.4 — Test the LLM Service Thoroughly
**Suggested Owner: Davi-Ann — document everything**

- [ ] Collect at least 15 receipt images covering the following variety:
  - [ ] At least 3 clear printed supermarket receipts (Hi-Lo, PriceSmart, Super Value, or similar)
  - [ ] At least 2 thermal restaurant or fast food receipts (KFC, Juici Patties, or similar)
  - [ ] At least 1 gas station receipt (Rubis, Texaco, Petcom, or similar)
  - [ ] At least 1 pharmacy receipt (Fontana, Generika, or similar)
  - [ ] At least 1 utility or service receipt (JPS, FLOW, NWC, or similar)
  - [ ] At least 2 low-quality images — one blurry and one photographed at an angle — to understand failure modes
- [ ] Write at least 15 text description test cases covering the following variety:
  - [ ] A description with a specific dollar amount and a named Jamaican merchant
  - [ ] A description with an approximate amount ("about $3,000")
  - [ ] A description with no merchant name
  - [ ] A description that says "today" for the date
  - [ ] A description that says "yesterday"
  - [ ] A description with a specific date mentioned
  - [ ] A description that lists multiple items
  - [ ] A description of a utility payment
  - [ ] A description of transport (bus fare, gas, taxi)
  - [ ] A description that is very short and minimal ("lunch $850")
  - [ ] A description that is ambiguous about the category
  - [ ] A description in Jamaican casual English phrasing
  - [ ] A description with amounts in USD
  - [ ] A description of a recurring payment like a subscription
  - [ ] A description of a split bill or shared expense
- [ ] Run all 30 test cases through `backend/test_llm.py` and for each one record:
  - The input (image filename or the exact text string)
  - The full JSON output received
  - A rating for each extracted field: correct, incorrect, or not applicable
  - Any notes on what went wrong
- [ ] Identify the top 3 failure patterns from the test results
- [ ] Adjust the LLM prompt language to address those failure patterns and retest
- [ ] Document all findings including the prompt changes made in `docs/llm_test_results.md`
- [ ] Commit `docs/llm_test_results.md` to the `feature/llm-pipeline` branch

---

### 3.5 — Auth Middleware
**Suggested Owner: Davi-Ann**

- [ ] Create `backend/middleware/auth.py`
- [ ] Implement a `verify_token` dependency function that: reads the `Authorization` header from the incoming request, expects a `Bearer` token format, decodes the token using PyJWT against the `SUPABASE_JWT_SECRET` environment variable with the `HS256` algorithm and the `authenticated` audience claim, returns the decoded payload containing the user ID and email if valid, and raises an HTTP 401 error with an appropriate message if the token is missing, expired, or invalid
- [ ] Test the middleware manually: call a protected endpoint with a valid Supabase JWT (obtainable by logging in via Supabase Auth in a test Flutter run or via the Supabase dashboard) and confirm it succeeds — then call it with an invalid token and confirm a 401 is returned

---

### 3.6 — LLM HTTP Endpoints
**Suggested Owner: Davi-Ann**

- [ ] Create `backend/routers/process.py`
- [ ] Create a POST endpoint at `/process/receipt-image` that: requires the auth middleware, accepts a multipart file upload, validates that the file content type is JPEG, PNG, or WebP, validates that the file size does not exceed 10 megabytes, passes the image bytes to `parse_receipt_image` from the LLM service, returns a JSON response with `success: true` and the extracted data, and returns appropriate HTTP error responses (400 for validation failures, 500 for LLM failures) with user-friendly messages
- [ ] Create a POST endpoint at `/process/text-description` that: requires the auth middleware, accepts a JSON request body with a `text` field, validates that the text is at least 5 characters and no more than 1,000 characters, passes the text and today's date to `parse_text_description`, returns the same response shape as the image endpoint, and handles errors consistently
- [ ] Register the `process` router in `main.py`
- [ ] Confirm both endpoints appear and are testable in the FastAPI interactive documentation at `http://localhost:8000/docs`
- [ ] Test both endpoints with a valid Supabase JWT attached and confirm the auth middleware is working on both

---

### 3.7 — Export Endpoints
**Suggested Owner: Shemar**

- [ ] Create `backend/routers/transactions.py`
- [ ] Create a GET endpoint at `/transactions/export` that: requires the auth middleware, accepts query parameters for `format` (csv or pdf), `start_date`, and `end_date`, queries the Supabase `transactions` table for the authenticated user's transactions within the date range ordered by date descending, and branches based on the format parameter:
  - For CSV: builds a CSV in memory with columns for Date, Merchant Name, Category, Source, Currency, and Amount — one row per transaction — and returns it with the content type set to `text/csv` and a content-disposition header prompting a file download
  - For PDF: uses ReportLab to build a PDF containing the app title, the date range, a summary section with total transactions and total amount spent, and a formatted transaction table — returns it with the appropriate PDF content type and download headers
- [ ] Test both export formats: download the files and open them to confirm the content is correct and the files open without errors
- [ ] Register the `transactions` router in `main.py`

---

### 3.8 — Deploy FastAPI to Railway
**Suggested Owner: Shemar**

- [ ] Create a file named `Procfile` in the `backend/` folder — it must contain a single line instructing Railway to start Uvicorn bound to the host `0.0.0.0` and the port provided by the `$PORT` environment variable
- [ ] Go to railway.app and create a new project
- [ ] Connect the GitHub repository to Railway
- [ ] In the Railway project settings, set the root directory to `backend/` so Railway looks in the right folder for the project
- [ ] In the Railway project Variables panel, add all environment variables from `.env.example` with their real values — never put these in committed code
- [ ] Trigger a deployment and wait for it to complete
- [ ] Test the deployed health endpoint at the Railway-provided URL — confirm it returns a status ok response
- [ ] Copy the Railway production URL and add it to `lib/core/constants.dart` in the Flutter project as a constant named `API_BASE_URL`
- [ ] Commit the constants file change to `dev`

---

### 3.9 — Final LLM Accuracy Report
**Suggested Owner: Davi-Ann**

- [ ] After the Railway deployment is live, re-run all 30 test cases against the production endpoint (not localhost) using a real Supabase auth token
- [ ] Calculate accuracy percentages: for each extracted field (merchant, amount, date, category), divide the number of correct extractions by the total test cases and multiply by 100
- [ ] If any field is below 70% accuracy, adjust the prompt, redeploy, and retest before writing the final report
- [ ] Write the final `docs/llm_accuracy_report.md` containing: total test cases run, accuracy per field, the most common failure cases with examples, prompt iterations made during development, and an honest conclusion on whether the accuracy is suitable for a production demo
- [ ] Commit the report

---

---

# PHASE 4 — Bank Integration and CSV Import
**Suggested Owner:** Reynaldo
**Deadline:** End of Week 4 | Branch: `feature/backend`

---

### 4.1 — Plaid Setup

- [ ] Install `plaid-python` in the `backend/` virtual environment and update `requirements.txt`
- [ ] Create `backend/services/plaid_service.py`
- [ ] Initialize the Plaid API client in the service file using `PLAID_CLIENT_ID`, `PLAID_SECRET`, and `PLAID_ENV` from the environment variables — use the Sandbox environment

---

### 4.2 — Plaid Link Token Endpoint

- [ ] Create `backend/routers/plaid_router.py`
- [ ] Create a POST endpoint at `/plaid/link-token` that: requires the auth middleware, calls the Plaid `link_token_create` method using the authenticated user's ID, and returns the generated link token to the Flutter app
- [ ] Register the Plaid router in `main.py`
- [ ] Test the endpoint: call it with a valid JWT and confirm a link token string is returned

---

### 4.3 — Plaid Exchange Token Endpoint

- [ ] Create a POST endpoint at `/plaid/exchange-token` that: requires the auth middleware, accepts a JSON body containing a `public_token` field, calls the Plaid `item_public_token_exchange` method to get a permanent access token, encrypts the access token using the `cryptography` library's Fernet symmetric encryption with the `ENCRYPTION_KEY` environment variable before storing it — the raw unencrypted token must never be written to the database, inserts the encrypted token along with the item ID and account ID into the Supabase `accounts` table for the authenticated user, and returns a success response with the new account details
- [ ] Test: complete the Plaid Sandbox link flow, call the exchange endpoint, and confirm an encrypted token appears in the Supabase `accounts` table

---

### 4.4 — Plaid Transaction Sync Endpoint

- [ ] Create a POST endpoint at `/plaid/sync-transactions` that: requires the auth middleware, retrieves all of the authenticated user's accounts that have a Plaid access token from Supabase, decrypts each stored access token using the same Fernet key, calls the Plaid `transactions_get` method for the last 30 days for each account, iterates through every transaction returned by Plaid and checks whether a row with the same `plaid_transaction_id` already exists in the Supabase `transactions` table — if it exists, skip it; if it does not exist, insert it as a new row with the source set to bank-sync, and returns a summary containing the count of new transactions inserted and the count of duplicates skipped
- [ ] Test: trigger the sync endpoint, confirm new transactions appear in Supabase, trigger it again and confirm no duplicates are created

---

### 4.5 — Scheduled Daily Auto-Sync

- [ ] In `backend/main.py`, configure an APScheduler background scheduler to run a `sync_all_users` function once per day at 2:00 AM
- [ ] Implement `sync_all_users` as a function that: queries Supabase for all account rows where `plaid_access_token` is not null (meaning they are bank-linked), groups them by user ID, runs the sync logic for each user, and logs a result line for each user showing how many new transactions were inserted and how many were skipped
- [ ] Start the scheduler when the FastAPI app starts up using a lifespan event
- [ ] Confirm the scheduler starts without errors in the Railway deployment logs

---

### 4.6 — CSV Import Endpoint

- [ ] Create a POST endpoint at `/transactions/import-csv` in `backend/routers/transactions.py` that: requires the auth middleware, accepts a multipart CSV file upload, reads and parses the CSV rows expecting columns for date, description, amount, and transaction type (debit or credit), for each row passes the description text to the `parse_text_description` function from the LLM service to automatically categorize the transaction, inserts each parsed transaction into the Supabase `transactions` table with the source set to bank-sync, collects any rows that fail to parse, and returns a summary with the count of successfully imported rows, the count of errored rows, and the details of each errored row
- [ ] Test using a realistic CSV export from a Jamaican bank statement — NCB and Scotiabank Jamaica both allow CSV exports from their online banking portals
- [ ] Confirm imported transactions appear in Supabase with correct categories

---

---

# PHASE 5 — Flutter Frontend
**Suggested Owner:** Shae and Reynaldo
**Deadline:** End of Week 6 | Branch: `feature/frontend`
**Prerequisite:** Pull the latest `dev` branch. The LLM pipeline (Phase 3) must be merged before starting the API service class.

---

### 5.1 — Core Architecture Files
**Suggested Owner: Reynaldo**

- [ ] Create `lib/core/supabase_client.dart` — initialize Supabase with the project URL and anonymous key passed in via `--dart-define` at build time, not hardcoded — expose a `supabase` getter for use throughout the app
- [ ] Create `lib/core/constants.dart` containing: the `API_BASE_URL` pointing to the Railway deployment, the ordered list of 9 category names (Groceries, Dining, Transport, Healthcare, Utilities, Entertainment, Shopping, Education, Other), a map of category names to their corresponding icons, and the app's color constants matching the Figma design system
- [ ] Create `lib/services/api_service.dart` with: a `processReceiptImage(File image)` method that compresses the image, sends it as a multipart upload to the `/process/receipt-image` FastAPI endpoint with the user's Supabase JWT as a Bearer token in the Authorization header, and returns a `ParsedTransaction` model — and a `processTextDescription(String text)` method that sends text to `/process/text-description` with the same auth header and returns the same model — both methods throw typed Dart exceptions for 400, 401, and 500 responses with messages the UI can display to the user
- [ ] Create `lib/models/parsed_transaction.dart` — a data class matching the agreed LLM output structure with fields for merchant name, amount, currency, date, category, description, confidence, and line items
- [ ] Create `lib/models/transaction.dart` — a data class matching all columns of the Supabase `transactions` table with a `fromJson` factory constructor
- [ ] Create `lib/models/budget.dart` — matching the `budgets` table with a `fromJson` factory
- [ ] Create `lib/models/account.dart` — matching the `accounts` table with a `fromJson` factory
- [ ] Create `lib/providers/auth_provider.dart` — exposes the current Supabase user via a Riverpod provider and streams auth state changes
- [ ] Create `lib/providers/transactions_provider.dart` — fetches and caches transactions from Supabase with support for filtering by date range, category, and search term — exposes a method to reload data
- [ ] Create `lib/providers/budgets_provider.dart` — fetches all budgets from Supabase and for each budget calculates the total spent in that category during the budget period using a separate transactions query — exposes this as a list of budget objects with the spent amount attached
- [ ] Create `lib/providers/accounts_provider.dart` — fetches the user's accounts from Supabase
- [ ] Create `lib/core/router.dart` using go_router — define all named routes, add a redirect guard that sends users without a valid auth session to `/login` and prevents authenticated users from reaching the login screen directly

---

### 5.2 — Authentication Screens
**Suggested Owner: Reynaldo**

- [ ] Create the Splash screen — display the app logo centered on screen, wait 1.5 seconds, check the auth provider, navigate to `/dashboard` if logged in or `/onboarding` (first time) or `/login` (returning user not logged in)
- [ ] Create the Onboarding screen — implement a `PageView` widget with 3 slides matching the Figma designs, add a Skip button that navigates directly to Login, add a Next button that advances pages, replace Next with a Get Started button on the last slide that navigates to Login, use `SharedPreferences` to write a key `onboarding_complete` on completion so onboarding only shows once
- [ ] Create the Sign Up screen with the following behavior:
  - [ ] All four fields — full name, email, password, confirm password — are required
  - [ ] Validate email format using a Dart regular expression
  - [ ] Validate password is at least 8 characters
  - [ ] Validate passwords match
  - [ ] On tap of the Sign Up button, call `supabase.auth.signUp` passing the email, password, and name in the `data` metadata map
  - [ ] On success, navigate to the Dashboard — the Supabase trigger creates the profile row automatically
  - [ ] On failure, display an inline error message directly below the relevant field — do not use a dialog
- [ ] Create the Login screen with the following behavior:
  - [ ] On tap of Log In, call `supabase.auth.signInWithPassword` with email and password
  - [ ] On success, navigate to the Dashboard
  - [ ] On failure, display an inline error message
  - [ ] Check if the device supports biometrics using `local_auth` — if yes, show a biometric button that authenticates with the device and retrieves the stored Supabase session from `flutter_secure_storage` to log the user in without a password
  - [ ] The Forgot Password link calls `supabase.auth.resetPasswordForEmail` and shows an inline confirmation message that an email was sent

---

### 5.3 — Dashboard Screen
**Suggested Owner: Shae**

- [ ] Create `lib/screens/dashboard/dashboard_screen.dart`
- [ ] At the top, show a greeting with the user's name pulled from the `auth_provider`
- [ ] Fetch the current month's transactions from the `transactions_provider`
- [ ] Render the monthly summary card: total spent this month, total budget across all active monthly budgets (from `budgets_provider`), and a colored `LinearProgressIndicator` that is green below 70%, orange between 70% and 99%, and red at 100% or above
- [ ] Render the category donut chart using `fl_chart` — calculate each category's total from the current month's transactions and map it to a `PieChartSectionData` — tapping a section filters the transaction list below to that category
- [ ] Render a list of the 5 most recent transactions, each row showing the category icon from the constants map, merchant name, formatted date using `intl`, and amount formatted as `JMD #,##0.00`
- [ ] Add a `FloatingActionButton` that expands into a speed dial with three labeled options: Scan Receipt navigating to `/scan`, Type Transaction navigating to `/text-input`, and Link Bank navigating to `/bank-link`
- [ ] Add `RefreshIndicator` (pull-to-refresh) that calls the provider's reload method
- [ ] Show a `CircularProgressIndicator` centered on screen while data is loading
- [ ] Show an empty state widget with an icon and descriptive text if there are no transactions

---

### 5.4 — Receipt Scan Flow
**Suggested Owner: Shae**

- [ ] Create `lib/screens/scan/scan_screen.dart`
- [ ] Initialize the `camera` package and display a live camera preview filling the screen
- [ ] Add a circular capture button at the bottom center
- [ ] Add an upload from gallery button in the corner using `image_picker`
- [ ] When the user captures or selects an image: upload the image file to Supabase Storage at the path `{user_id}/{timestamp}.jpg` using the Supabase client, get back the storage path, show a full-screen loading overlay with the text "Reading your receipt…", call `api_service.processReceiptImage` with the image file, on success navigate to the Confirmation screen passing both the `ParsedTransaction` result and the Supabase storage path, on failure show a dialog offering to try again or switch to manual entry
- [ ] Create `lib/screens/confirm/confirm_transaction_screen.dart` — this screen is shared by both the scan flow and the text input flow — it must accept a `ParsedTransaction` object and optionally a receipt image path or original input text as constructor parameters
- [ ] In the Confirmation screen, render:
  - [ ] A receipt image thumbnail using the Supabase Storage URL if the source is OCR, or a text icon if the source is text input
  - [ ] An editable `TextFormField` for merchant name — pre-filled from `parsedTransaction.merchantName`
  - [ ] An editable `TextFormField` with a decimal numeric keyboard for amount — pre-filled
  - [ ] A currency `DropdownButtonFormField` with options JMD, USD, TTD, BBD — pre-selected from `parsedTransaction.currency`
  - [ ] A date `TextFormField` with a `DatePicker` on tap — pre-filled from `parsedTransaction.date`
  - [ ] A category `DropdownButtonFormField` with all 9 categories — pre-selected from `parsedTransaction.category`
  - [ ] A `TextFormField` for optional description/notes
  - [ ] For any field where the corresponding `ParsedTransaction` value is null: apply an amber border to the field using the `InputDecoration`'s `enabledBorder` property and show a small label below the field reading "Please fill in"
  - [ ] A confidence badge in the top right of the form area — a colored dot and percentage text — green above 80%, yellow from 50–80%, red below 50% — a tooltip on tap explains what confidence means
  - [ ] A Save Transaction button that is disabled while any required null-originated field is empty — on tap, validate all required fields are filled, insert a new row into the Supabase `transactions` table with all field values, the receipt image path, the raw input text if applicable, the confidence score, and the source set to `ocr` or `text-input`, then navigate back to the Dashboard and show a `SnackBar` with "Transaction saved ✓"
  - [ ] A Discard button that shows a confirmation dialog before navigating back without saving

---

### 5.5 — Text Input Screen
**Suggested Owner: Reynaldo**

- [ ] Create `lib/screens/text_input/text_input_screen.dart`
- [ ] Render a large, padded `TextFormField` with `maxLines` set to 5, `maxLength` set to 500, and a `hintText` showing two example descriptions such as "bought lunch at the canteen for $850 today" and "paid FLOW bill $2,500 this morning"
- [ ] Show a character counter below the field
- [ ] Add a Process Transaction button — disable it if the text field is empty or under 5 characters
- [ ] On button tap: show a full-screen loading overlay with the text "Processing your transaction…", call `api_service.processTextDescription` with the trimmed text, on success navigate to the Confirmation screen passing the `ParsedTransaction` result and the original text string, on failure dismiss the overlay and show an inline error message below the text field allowing the user to edit and try again

---

### 5.6 — Transaction List and Detail Screens
**Suggested Owner: Reynaldo**

- [ ] Create `lib/screens/transactions/transaction_list_screen.dart`
- [ ] Fetch transactions from the `transactions_provider` — start with the first 20 and load more automatically when the user scrolls to within 200 pixels of the bottom
- [ ] Add a `SearchBar` widget at the top that filters the displayed list by matching the search text against `merchant_name` and `description` fields — filter is applied locally to the cached provider data
- [ ] Add a filter row below the search bar containing a category dropdown (defaulting to "All Categories") and a date range selector — changes trigger a new provider fetch with the updated filter parameters
- [ ] Each list item row must show: the category icon from the constants map, the merchant name in body text, the formatted date in caption text, the amount formatted as JMD currency right-aligned, and a small source badge reading OCR, Text, Bank, or Manual depending on the `source` field
- [ ] Show a `CircularProgressIndicator` centered while the initial load is in progress
- [ ] Show an empty state widget when the filtered result is empty
- [ ] Create `lib/screens/transactions/transaction_detail_screen.dart`
- [ ] Accept a `Transaction` object as a parameter and display all fields in labeled rows
- [ ] If `receipt_image_path` is not null: fetch the signed URL from Supabase Storage and render a tappable image thumbnail — tapping opens a full-screen image viewer
- [ ] If `raw_llm_input` is not null: render a light-colored card below the main fields showing "Originally entered as:" followed by the text in italic
- [ ] If `source` equals `bank-sync`: render a card showing the Plaid transaction metadata
- [ ] Add an Edit button that switches the merchant name, category, description, and amount fields into editable state — replaced with an Update button that saves changes to Supabase
- [ ] Add a Delete button that shows a `showDialog` confirmation — on confirmation, deletes the Supabase row and uses `context.pop()` to navigate back to the list

---

### 5.7 — Bank Link Screen
**Suggested Owner: Reynaldo**

- [ ] Create `lib/screens/bank_link/bank_link_screen.dart`
- [ ] On screen initialization, call the FastAPI `/plaid/link-token` endpoint using `api_service` and store the returned link token in local state
- [ ] Use `webview_flutter` to load the Plaid Link hosted URL with the link token embedded as a query parameter — the exact URL format is documented in the Plaid Sandbox documentation
- [ ] Intercept the WebView navigation to detect when Plaid's success callback fires and passes a public token back — extract the public token from the callback URL parameters
- [ ] On receiving the public token: dismiss the WebView, show a loading indicator with "Linking your account…", call the FastAPI `/plaid/exchange-token` endpoint with the public token, on success show a confirmation message with the linked account name, call the FastAPI `/plaid/sync-transactions` endpoint immediately, on sync completion show a message like "12 new transactions synced" and navigate back to the Dashboard
- [ ] Handle the Plaid Link cancelled case gracefully — simply dismiss the WebView and show a message that the user can link a bank account any time from Settings
- [ ] Below the Plaid section, add a divider and a clearly labeled Import Bank Statement section with a brief explanation that users can export a CSV from their bank's online portal, an Import CSV button that opens the device file picker filtered to CSV files, on file selection sends the file to the FastAPI `/transactions/import-csv` endpoint, and on completion shows the import summary (e.g., "34 transactions imported, 2 errors")

---

### 5.8 — Budget Screens
**Suggested Owner: Shae**

- [ ] Create `lib/screens/budgets/budget_overview_screen.dart`
- [ ] Fetch data from the `budgets_provider` which returns budgets with the spent amount pre-calculated
- [ ] For each budget, render a card containing: the category icon and name, the budget period and date range, the formatted budget amount, the formatted amount spent, the number of days remaining, and an animated `LinearProgressIndicator` — green below 70%, orange between 70% and 99%, red at 100% or above
- [ ] Show an "Over Budget!" badge using a colored container overlay on the card when `spent >= amount`
- [ ] Show a `CircularProgressIndicator` while loading, an empty state when no budgets exist
- [ ] Add a `FloatingActionButton` navigating to the create budget screen
- [ ] Create `lib/screens/budgets/create_edit_budget_screen.dart`
- [ ] Accept an optional existing `Budget` object — if provided, the screen is in edit mode and pre-fills all fields
- [ ] Render: a category `DropdownButtonFormField`, an amount `TextFormField` with a decimal numeric keyboard, a period toggle using `ChoiceChip` widgets for Monthly and Weekly, a start date picker, and an end date picker
- [ ] Validate: amount greater than zero, category selected, end date after start date — show inline errors
- [ ] In edit mode, show a Delete button that presents a confirmation dialog and on confirmation deletes the budget and navigates back
- [ ] The Save button inserts or updates the row in Supabase and navigates back

---

### 5.9 — Reports Screen
**Suggested Owner: Shae**

- [ ] Create `lib/screens/reports/reports_screen.dart`
- [ ] Add four preset `ChoiceChip` widgets at the top: This Month, Last Month, Last 3 Months, Custom — selecting any preset updates the active date range and refreshes all data below
- [ ] When Custom is selected, show `showDateRangePicker` and update the range from its result
- [ ] Fetch transactions filtered to the active date range from Supabase
- [ ] Render three summary stat cards: total amount spent (formatted as JMD currency), top spending category (the category with the highest total), and total number of transactions
- [ ] Render a bar chart using `fl_chart` showing month-over-month total spending for the last 6 months — each bar represents one calendar month — the current month's bar is highlighted
- [ ] Render a category breakdown table with columns for Category, Amount Spent, and Percentage of Total — sorted from highest to lowest — using the `intl` package for all formatting
- [ ] Add an Export PDF button that: calls the FastAPI `/transactions/export?format=pdf` endpoint with the current date range and the user's JWT, receives the PDF bytes, writes them to a temporary file on the device using `path_provider`, and opens the file with `open_filex`
- [ ] Add an Export CSV button that: calls the same endpoint with `format=csv`, writes the CSV bytes to a temporary file, and shares it using `share_plus` so the user can save or send it

---

### 5.10 — Settings Screen
**Suggested Owner: Reynaldo**

- [ ] Create `lib/screens/settings/settings_screen.dart`
- [ ] Profile section: show the user's name and email in read-only `ListTile` widgets
- [ ] Linked Accounts section: render a list of accounts from the `accounts_provider` — each bank account shows the institution name — each entry has a trailing Remove button that deletes the account row from Supabase after a confirmation dialog — an Add Bank Account `ListTile` at the bottom navigates to the Bank Link screen
- [ ] CSV Import `ListTile` that navigates to the Bank Link screen scrolled to the import section
- [ ] Notifications section: a `SwitchListTile` labeled Budget Alerts — its value comes from the `biometric_enabled` field in the user's profile row — toggling it sends a Supabase update to the profile row
- [ ] Security section: a `SwitchListTile` labeled Biometric Login — its value comes from the profile row — toggling on saves the preference to the profile and to `flutter_secure_storage`, toggling off removes it
- [ ] Data section: a Sync Now `ListTile` that calls the FastAPI `/plaid/sync-transactions` endpoint, shows a `CircularProgressIndicator` in the trailing position while running, and shows the result in a `SnackBar`
- [ ] Logout `ListTile` at the bottom with a warning icon — tapping shows a confirmation dialog — on confirmation calls `supabase.auth.signOut()` and uses the router to navigate to `/login`

---

### 5.11 — Push Notifications
**Suggested Owner: Reynaldo (Flutter side), Shae (FastAPI side)**

**Flutter side:**
- [ ] In `lib/main.dart`, after Supabase initializes, initialize `FirebaseApp` using `Firebase.initializeApp()`
- [ ] After initialization, get the FCM registration token using `FirebaseMessaging.instance.getToken()`
- [ ] Update the authenticated user's `fcm_token` field in the Supabase `profiles` table with this token
- [ ] Request notification permissions using `FirebaseMessaging.instance.requestPermission()` — this is required for Android 13 and above
- [ ] Register a `FirebaseMessaging.onMessage` listener that fires when a notification arrives while the app is in the foreground — display it as an in-app banner using `flutter_local_notifications`
- [ ] Register a `FirebaseMessaging.onMessageOpenedApp` listener that fires when the user taps a notification while the app is in the background — read the notification payload and use the router to navigate to `/budgets`

**FastAPI side:**
- [ ] In `backend/services/notification_service.py`, initialize the Firebase Admin SDK using a service account JSON file from the Firebase project settings — store this file path in the environment variables, never commit the file
- [ ] Implement a `send_budget_alert(user_id, category, percentage, fcm_token)` function that uses the Firebase Admin SDK to send a push notification with a title such as "Budget Alert" and a body such as "You've used 80% of your Dining budget"
- [ ] In the FastAPI route that handles transaction insertion (triggered when the Flutter app confirms a new OCR or text input transaction), after the Supabase insert: query the `budgets` table for any active budgets matching the transaction's category and user ID, calculate the total spent in that category during each matching budget period, for each budget where the percentage has crossed 80% and `alert_sent_80` is false — call `send_budget_alert`, then update `alert_sent_80` to true in Supabase, repeat the same logic for 100% using `alert_sent_100`

---

### 5.12 — UI Polish Pass
**Both Shae and Reynaldo — required before Phase 6 begins**

Go through every single screen with this checklist. Every item must be true before the frontend is considered complete.

- [ ] Every screen that loads data shows a `CircularProgressIndicator` or skeleton loader while loading — no blank white screens
- [ ] Every screen that can have an API or database error shows a user-friendly message and a Retry button
- [ ] Every screen that can have no data shows an empty state with an icon and a helpful message
- [ ] Every money value throughout the app is formatted using `NumberFormat.currency(locale: 'en_JM', symbol: 'JMD ')` from the `intl` package
- [ ] Every date is formatted in a human-readable style such as "March 1, 2026" or "Mon, Mar 1" using `DateFormat` from the `intl` package
- [ ] Every amount input field uses `TextInputType.numberWithOptions(decimal: true)` as its keyboard type
- [ ] The app displays a non-blocking offline banner at the top of the screen when there is no network connection — detect this using a network connectivity check
- [ ] Category icons are consistent in every location they appear — all sourced from the same icon map in `constants.dart`
- [ ] The app has been installed and tested on at least one physical Android device by each developer
- [ ] The Windows desktop build has been tested using `flutter build windows --release`

---

---

# PHASE 6 — Integration and End-to-End Testing
**Suggested Owner:** All members
**Deadline:** End of Week 7

---

### 6.1 — Merge All Branches

- [ ] Submit a PR from `feature/llm-pipeline` into `dev` — reviewed and merged
- [ ] Submit a PR from `feature/backend` into `dev` — reviewed and merged
- [ ] Submit a PR from `feature/frontend` into `dev` — reviewed and merged
- [ ] After all three merges, every member pulls the latest `dev` and confirms the app builds and runs without errors on their device

---

### 6.2 — Integration Test Journey 1: New User Registration

- [ ] Open the app on a physical Android device (not the emulator)
- [ ] Confirm the splash screen appears and transitions correctly
- [ ] Go through all 3 onboarding slides, confirm the Skip button works, confirm Get Started navigates to Login
- [ ] Sign up with a new email address
- [ ] Confirm navigation lands on the Dashboard in an empty state
- [ ] Open the Supabase dashboard and confirm a profile row was automatically created for the new user

---

### 6.3 — Integration Test Journey 2: Receipt Scan to Saved Transaction

- [ ] From the Dashboard, tap the floating action button and select Scan Receipt
- [ ] Photograph a real physical receipt
- [ ] Confirm the loading overlay appears with the correct message
- [ ] Confirm the Confirmation screen appears with pre-filled fields
- [ ] Edit at least one field manually to verify editing works
- [ ] Tap Save Transaction
- [ ] Confirm the transaction appears in the Dashboard recent list
- [ ] Navigate to Transaction List and confirm the transaction appears with the OCR source badge
- [ ] Navigate to Transaction Detail and confirm all field values are correct
- [ ] Tap the receipt thumbnail and confirm the full-size image opens

---

### 6.4 — Integration Test Journey 3: Text Input to Saved Transaction

- [ ] From the Dashboard, tap the floating action button and select Type Transaction
- [ ] Type a natural language description of a purchase
- [ ] Tap Process Transaction and confirm the loading overlay appears
- [ ] Confirm the Confirmation screen appears with extracted fields
- [ ] Confirm the original text is shown in the source information card on the detail screen after saving
- [ ] Save and confirm the transaction appears in the Transaction List with the Text source badge

---

### 6.5 — Integration Test Journey 4: Bank Link and Sync

- [ ] Navigate to the Bank Link screen from the Dashboard FAB
- [ ] Complete the Plaid Sandbox link flow selecting any sandbox institution
- [ ] Confirm a success message appears with the linked account name
- [ ] Confirm the sync completes and a count of new transactions is shown
- [ ] Navigate to Transaction List and confirm the imported transactions appear with the Bank source badge
- [ ] Navigate to Settings and confirm the linked account appears in the Linked Accounts section

---

### 6.6 — Integration Test Journey 5: CSV Import

- [ ] Download a sample bank statement CSV from a test source or create a realistic one manually
- [ ] Navigate to the CSV import section on the Bank Link screen
- [ ] Select the CSV file
- [ ] Confirm the import summary is displayed with the expected counts
- [ ] Navigate to Transaction List and confirm all imported transactions appear

---

### 6.7 — Integration Test Journey 6: Budget Creation and Alerts

- [ ] Navigate to Budgets and create a new monthly budget for the Dining category with a specific JMD amount
- [ ] Add multiple dining transactions until the total reaches exactly 80% of the budget
- [ ] Confirm a push notification arrives on the device with the 80% message
- [ ] Confirm the budget card on the Budget Overview screen shows the orange color and correct percentage
- [ ] Add one more transaction that pushes the total over 100% of the budget
- [ ] Confirm a second push notification arrives with the 100% message
- [ ] Confirm the budget card turns red and shows the Over Budget badge

---

### 6.8 — Integration Test Journey 7: Report Export

- [ ] Navigate to the Reports screen
- [ ] Select the This Month preset
- [ ] Verify the total spent and transaction count match the Transaction List screen for the same period
- [ ] Tap Export PDF and confirm the file opens on the device with correct content
- [ ] Tap Export CSV and confirm the file can be shared and opened in a spreadsheet viewer

---

### 6.9 — Integration Test Journey 8: Logout and Re-login

- [ ] Navigate to Settings and tap Logout
- [ ] Confirm navigation returns to the Login screen
- [ ] Confirm no user data is visible on the Login screen
- [ ] Log back in with the same credentials
- [ ] Confirm all previous transactions, budgets, and linked accounts are still present

---

### 6.10 — Bug Tracking

- [ ] Every team member creates a GitHub Issue for every problem found during Journeys 1–8
- [ ] Each issue must include: a title specifying the affected screen or feature, numbered reproduction steps, expected behavior, actual behavior, and a screenshot or screen recording if possible
- [ ] Label each issue as P1 (crash or data loss), P2 (wrong behavior but no data loss), or P3 (cosmetic or minor)
- [ ] Assign each issue to the team member who built the affected module

---

### 6.11 — Bug Fix Sprint

- [ ] Resolve all P1 issues before touching anything else — no P2 work while any P1 is open
- [ ] Resolve all P2 issues after all P1s are closed
- [ ] Address P3 issues only if time permits
- [ ] Each fix is committed separately with a message referencing the issue number (e.g., `fix: crash on empty LLM response (#23)`)
- [ ] After fixing each issue, re-run the relevant test journey from 6.2–6.9 to confirm it is resolved

---

### 6.12 — Performance Check

- [ ] Dashboard must load within 3 seconds from a cold start on a mid-range Android device
- [ ] LLM receipt processing must complete within 8 seconds from image capture to the Confirmation screen appearing
- [ ] LLM text processing must complete within 4 seconds from button tap to the Confirmation screen appearing
- [ ] Plaid sync must complete within 15 seconds for a standard 30-day sync
- [ ] All Supabase queries must respond within 1 second under normal network conditions
- [ ] Record the actual measured times in `docs/technical_decisions.md` and flag any that exceed these targets for optimization

---

---

# PHASE 7 — Deployment and Demo Preparation
**Deadline:** End of Week 7 (deployment) | End of Week 8 (demo ready)

---

### 7.1 — Production Build

- [ ] Confirm FastAPI on Railway shows no errors in the production logs
- [ ] Confirm the Railway health endpoint is responding correctly
- [ ] Build the release Android APK using Flutter's build command with all Supabase credentials passed in via `--dart-define` flags — not hardcoded
- [ ] Install the release APK on at least two different physical Android devices (not emulators)
- [ ] Confirm the app launches, logs in, and performs a receipt scan successfully on both devices
- [ ] Build the Windows release using `flutter build windows --release`
- [ ] Confirm the Windows app launches and the core flows work
- [ ] Add the following permissions to `android/app/src/main/AndroidManifest.xml` if not already present: INTERNET, CAMERA, READ_EXTERNAL_STORAGE or READ_MEDIA_IMAGES (API 33+), USE_BIOMETRIC, and POST_NOTIFICATIONS (API 33+)
- [ ] Fix any release-mode specific issues — these commonly include missing manifest permissions, the debug signing configuration not working for release builds, and HTTP traffic being blocked because HTTPS is required for production

---

### 7.2 — Demo Data Setup

- [ ] Agree on a single shared demo user account — all team members know the credentials — store them in the shared private Google Doc
- [ ] Load at least 25 realistic Jamaican transactions into the demo account spanning 2 months:
  - [ ] At least 5 different categories represented
  - [ ] At least 5 transactions with source set to OCR (scan flow)
  - [ ] At least 5 transactions with source set to text-input
  - [ ] At least 10 transactions with source set to bank-sync (from Plaid Sandbox)
  - [ ] All amounts in JMD with realistic values for Jamaica
  - [ ] Merchant names matching real Jamaican businesses
  - [ ] Dates spread across the two-month period
- [ ] Create 4 budgets for different categories:
  - [ ] One at under 50% used — shows the green healthy state
  - [ ] One at approximately 80% — shows the orange warning state and a sent alert
  - [ ] One at over 100% — shows the red over-budget state and a sent alert
  - [ ] One with minimal spending — contrasts the others visually
- [ ] Link a Plaid Sandbox bank account to the demo account and confirm transactions are synced
- [ ] Do a full walkthrough of the demo account on the demo device and confirm everything looks clean and professional before Week 8

---

### 7.3 — Backup Plan for Demo Day

- [ ] Pre-record a 3-minute screen recording showing the complete receipt scan flow from camera capture to saved transaction — save this video to a shared Google Drive folder that all team members can access from their phones
- [ ] Save the release APK to a USB drive as an installation backup
- [ ] Confirm the demo user account has enough pre-loaded data that the Dashboard, Reports, and Budget screens look professional even if no new transactions are added live during the presentation

---

### 7.4 — Presentation Structure (15 minutes)

- [ ] Assign a speaker to each segment before the Week 8 Friday rehearsal:
  - [ ] Segment 1 — Problem Statement (2 minutes): The cost of living in Jamaica, the gap in local personal finance tools, and what ClearLedger addresses
  - [ ] Segment 2 — Architecture Overview (2 minutes): Walk through a diagram of the system — Flutter app, Supabase, FastAPI on Railway, the LLM API, Plaid — explain how each component connects
  - [ ] Segment 3 — Live Demo: Receipt Scan Flow (2 minutes): Photograph a real receipt live, walk through the Confirmation screen, save, and show the transaction in the ledger
  - [ ] Segment 4 — Live Demo: Text Input Flow (1 minute): Type a description live, process it, confirm and save
  - [ ] Segment 5 — Live Demo: Dashboard and Budget Alerts (2 minutes): Show the category chart, the budget overview screen, and reference the alerts that were already sent for the demo account
  - [ ] Segment 6 — Live Demo: Bank Sync and Report Export (1 minute): Show the synced bank transactions, export a PDF report, and open it
  - [ ] Segment 7 — Technical Depth (2 minutes): LLM accuracy numbers from `docs/llm_accuracy_report.md`, prompt engineering iterations, Supabase schema decisions
  - [ ] Segment 8 — Limitations and Future Work (1 minute): Plaid not supporting Jamaican banks, CSV import as the current solution, and what would be built next
  - [ ] Segment 9 — Q&A (2 minutes): All members answer
- [ ] Prepare written answers to each of the following questions in case they are asked:
  - [ ] What happens if the LLM is unavailable or rate-limited during the demo?
  - [ ] How does this app work for real Jamaican bank users today, given Plaid limitations?
  - [ ] How is user financial data kept secure?
  - [ ] If you had three more months, what would you build next?
- [ ] Build the slide deck in Google Slides — keep it minimal and visual, the live demo is the centerpiece
- [ ] Run a full rehearsal of the demo at the Week 8 Friday meeting
- [ ] Run a second full rehearsal before the presentation date

---

---

# PHASE 8 — Final Documentation and Submission
**Deadline:** End of Week 8

---

### 8.1 — Repository Cleanup
**All members check their own code**

- [ ] Remove all `print()` and debug log statements from the Flutter codebase
- [ ] Remove all `print()` statements from the FastAPI codebase
- [ ] Delete all commented-out code blocks throughout both projects
- [ ] Remove all test scripts and placeholder files from the `lib/` folder
- [ ] Remove all test scripts from `backend/` except `test_llm.py` which should be kept as documentation
- [ ] Confirm no real credentials, API keys, or tokens are present anywhere in committed files
- [ ] Confirm `.gitignore` is covering all sensitive files

---

### 8.2 — Documentation
**Each person is responsible for one section**

- [ ] **Reynaldo** — Write the root-level `README.md` covering: app description with at least two screenshots, setup instructions for the Flutter frontend, setup instructions for the FastAPI backend, a complete list of all environment variables and where to obtain each value, how to run the development server and the Flutter app, and the team member list with roles
- [ ] **Shemar** — Add Dart doc comments (`///`) above every public function in `lib/services/api_service.dart` and `lib/providers/` — each comment must explain what the function accepts, what it returns, and any edge cases to be aware of
- [ ] **Davi-Ann** — Finalize `docs/llm_accuracy_report.md` with the final production accuracy numbers from the integration test phase, a summary of every prompt change made, the known remaining failure cases, and an honest conclusion
- [ ] **Shae** — Export the final FastAPI endpoint collection from the Railway documentation page or Postman and commit it to `docs/api_reference.json` — ensure every endpoint has an example request and expected response documented

---

### 8.3 — Final Code Review

- [ ] Reynaldo reviews Shemar's LLM pipeline code via a pull request and approves or requests changes
- [ ] Shemar reviews Davi-Ann's auth middleware and export endpoints via a pull request and approves or requests changes
- [ ] Davi-Ann reviews Shae's backend and notification code via a pull request and approves or requests changes
- [ ] Shae reviews Reynaldo's Flutter core architecture and dashboard code via a pull request and approves or requests changes
- [ ] All four reviews are approved before the final merge

---

### 8.4 — Final Merge and Tag

- [ ] One person submits a PR from `dev` into `main`
- [ ] Confirm no merge conflicts
- [ ] Confirm the app builds from `main` without errors
- [ ] Create a release tag: `git tag v1.0.0` then `git push --tags`
- [ ] Submit the project as required by COMP3901 guidelines

---

---

## Friday Meeting Agenda (Every Week — 45–60 minutes)

1. Each person gives a 2-minute status: what was completed this week, what is being worked on next, what is blocking progress — be specific, not vague
2. Check this week's Friday checkpoint goal from the timeline table — mark it green (met) or red (not met) and assign tasks to close any gaps before next Friday
3. Review all open GitHub issues — close resolved ones, assign new ones, reprioritize if needed
4. Each person states one specific deliverable they commit to completing before next Friday
5. Any architecture decisions requiring a group vote — resolve them here, record the decision in `docs/technical_decisions.md`

---

## Risk Register

| Risk | Likelihood | Action |
|---|---|---|
| LLM returns invalid JSON | Medium | Both parsing functions must handle this gracefully and show a user-friendly retry message. The Confirmation screen's manual edit fields are the recovery path when extraction fails. |
| LLM rate limited during demo | Low | Free Gemini tier allows 15 requests per minute. More than enough for a live demo. Pre-cache demo extraction results as a fallback in case the network is down. |
| Plaid has no live Jamaican bank connections | High (known) | Expected and acceptable. Plaid Sandbox works perfectly for the demo. CSV import is the real-world solution. Address this directly in the Limitations segment of the presentation. |
| Schema change required mid-development | Medium | Any schema change after Week 2 requires a Friday team discussion. Changes go through `dev` immediately so all branches stay in sync. Announce all schema changes in the group chat the moment they are made. |
| Feature creep | High | Hard rule enforced every Friday: no new features after end of Week 5. All new ideas go into `docs/future_features.md`. |
| A team member is unavailable for a week or more | Medium | Every module must have commit history clear enough for another member to continue. Never hold uncommitted work for more than one day. |
| Release APK build fails | Medium | Test release builds starting Week 6. Never leave the first release build attempt until Week 7 or later. |

---

## Commit Message Convention

Use one of the following prefixes followed by a lowercase imperative description:
- `feat:` for new functionality
- `fix:` for bug corrections
- `chore:` for dependency updates and config changes
- `docs:` for documentation
- `refactor:` for restructuring without behavior change
- `test:` for adding or updating tests

Reference GitHub issue numbers where applicable. Example: `fix: confirmation screen crashes when confidence is null (#31)`

---

*ClearLedger — COMP3901 Capstone | Updated March 2026*
