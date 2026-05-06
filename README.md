# ClearLedger

ClearLedger is a mobile-first personal finance tracking Android app that eliminates manual data entry by extracting transaction details from receipt photos and natural language text using Large Language Models (LLMs).

## Features

- **Receipt Parsing (OCR):** Upload or snap a picture of a receipt, and Gemma 4 extracts merchant, amount, category, date, and line items.
- **Natural Language Parsing:** Type a description (e.g., "Bought lunch for $1500 jmd today") and Gemma 4 transforms it into a structured transaction.
- **Unified Ledger:** View, search, and filter all transactions.
- **Budgets:** Set monthly budgets per category and track usage.
- **Exporting:** Generate and download PDF and CSV reports of spending within a date range.
- **Push Notifications:** Automatic alerts when overspending budget limits.

## Tech Stack

- **Frontend:** Flutter (Dart), Firebase Cloud Messaging
- **Backend:** FastAPI (Python), deployed on Railway
- **Database:** Supabase (PostgreSQL with RLS, Auth, Storage)
- **AI Processing:** Google-hosted Gemma 4 (with Claude Sonnet fallback)

## Setup Guide

### 1. Supabase Setup
1. Create a project at [Supabase](https://supabase.com/).
2. Go to the SQL Editor and run the entire `supabase/schema.sql` script to create tables, RLS policies, and triggers.
3. Confirm the `receipts` storage bucket exists. The SQL script creates it if your Supabase role has storage permissions.
4. For quick local testing, either disable email confirmation in Supabase Auth settings or complete the email confirmation flow before trying to sign in.
5. Copy these values for the next steps:
   - Project URL
   - publishable key (`sb_publishable_...`)
   - secret key (`sb_secret_...`)

### 2. FastAPI Backend
From PowerShell:

1. Create and activate a virtual environment from the repo root:
   ```powershell
   py -3.11 -m venv .venv
   .\.venv\Scripts\Activate.ps1
   ```
2. Install dependencies:
   ```powershell
   python -m pip install -r backend\requirements.txt
   ```
3. Create the backend environment file:
   ```powershell
   Copy-Item backend\.env.example backend\.env
   ```
4. Fill in `backend\.env`:
   ```dotenv
   SUPABASE_URL=https://your-project-ref.supabase.co
   SUPABASE_PUBLISHABLE_KEY=sb_publishable_your-publishable-key
   SUPABASE_SECRET_KEY=sb_secret_your-secret-key
   GEMMA_API_KEY=your-google-ai-studio-api-key
   GEMMA_MODEL=gemma-4-31b-it
   ANTHROPIC_API_KEY=your-anthropic-api-key
   PORT=8000
   CORS_ORIGINS=*
   ```
5. Go to the backend folder and run the API:
   ```powershell
   cd backend
   python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
   ```
6. In another terminal, verify the backend is up:
   ```powershell
   Invoke-RestMethod http://127.0.0.1:8000/health
   ```

### 3. Flutter App
1. Install [Flutter SDK](https://docs.flutter.dev/get-started/install).
2. Go to the root directory `ClearLedger/`.
3. Generate the local platform folders that are not currently checked into this repo:
   ```powershell
   flutter create --platforms=android,windows .
   ```
4. Fetch dependencies and update `pubspec.lock`:
   ```powershell
   flutter pub get
   ```
5. Run on an Android emulator:
   ```powershell
   flutter run --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_your-publishable-key --dart-define=API_BASE_URL=http://10.0.2.2:8000
   ```
6. Run on Windows desktop:
   ```powershell
   flutter run -d windows --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_your-publishable-key --dart-define=API_BASE_URL=http://127.0.0.1:8000
   ```
7. Run on a physical Android device connected to the same network as your computer:
   ```powershell
   flutter run --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_your-publishable-key --dart-define=API_BASE_URL=http://YOUR_COMPUTER_LAN_IP:8000
   ```

## End-to-End Test Checklist

1. Start Supabase, or use the hosted Supabase project where you ran `supabase/schema.sql`.
2. Start the FastAPI backend and confirm `/health` returns `{"status":"ok","service":"ClearLedger API"}`.
3. Start Flutter with the correct `--dart-define` values for your target device.
4. Register a new account in the app.
5. Check Supabase `profiles` and confirm a profile row was created for that user.
6. Go to Add -> Text and enter `Spent 1200 JMD at Starbucks yesterday`.
7. Confirm the review screen shows merchant, amount, category, and date. Save it.
8. Open Ledger and confirm the transaction appears. Try search and category filtering.
9. Go to Budgets and create a Food budget lower than a test Food transaction.
10. Add or parse a Food transaction that exceeds the budget. Confirm the budget bar updates and a local notification appears when supported by the platform.
11. Go to Settings and export PDF and CSV for this month. Confirm both files open and contain your transaction.
12. Try receipt parsing with a clear JPEG or PNG receipt. Confirm the image parses, the review screen appears, and the saved transaction is visible in Ledger.

## Workflow & Safety
- **Review Transaction Screen:** Ensures human-in-the-loop review of AI-parsed data. The user confirms or corrects details before storing in the database.
- **Row-Level Security (RLS):** Enforced at the Supabase PostgreSQL level.
