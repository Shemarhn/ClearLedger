# ClearLedger

ClearLedger is a mobile-first personal finance tracking Android app (with Windows support) that eliminates manual data entry by extracting transaction details from receipt photos and natural language text using Large Language Models (LLMs).

## Features

- **Receipt Parsing (OCR):** Upload or snap a picture of a receipt, and Gemini 2.0 Flash extracts merchant, amount, category, date, and line items.
- **Natural Language Parsing:** Type a description (e.g., "Bought lunch for $1500 jmd today") and Gemini transforms it into a structured transaction.
- **Unified Ledger:** View, search, and filter all transactions.
- **Budgets:** Set monthly budgets per category and track usage.
- **Exporting:** Generate and download PDF and CSV reports of spending within a date range.
- **Push Notifications:** Automatic alerts when overspending budget limits.

## Tech Stack

- **Frontend:** Flutter (Dart), Firebase Cloud Messaging
- **Backend:** FastAPI (Python), deployed on Railway
- **Database:** Supabase (PostgreSQL with RLS, Auth, Storage)
- **AI Processing:** Google Gemini 2.0 Flash API (with Claude Sonnet fallback)

## Setup Guide

### 1. Supabase Setup
1. Create a project at [Supabase](https://supabase.com/).
2. Go to the SQL Editor and run the entire `supabase/schema.sql` script to create tables, RLS policies, and triggers.
3. Confirm the `receipts` storage bucket exists. The SQL script creates it if your Supabase role has storage permissions.
4. For quick local testing, either disable email confirmation in Supabase Auth settings or complete the email confirmation flow before trying to sign in.
5. Copy these values for the next steps:
   - Project URL
   - anon public key
   - service role key
   - JWT secret

### 2. FastAPI Backend
From PowerShell:

1. Go to the backend folder:
   ```powershell
   cd backend
   ```
2. Create and activate a virtual environment:
   ```powershell
   py -3.11 -m venv .venv
   .\.venv\Scripts\Activate.ps1
   ```
3. Install dependencies:
   ```powershell
   python -m pip install -r requirements.txt
   ```
4. Create the backend environment file:
   ```powershell
   Copy-Item .env.example .env
   ```
5. Fill in `.env`:
   ```dotenv
   SUPABASE_URL=https://your-project-ref.supabase.co
   SUPABASE_SERVICE_ROLE_KEY=your-supabase-service-role-key
   SUPABASE_JWT_SECRET=your-supabase-jwt-secret
   GEMINI_API_KEY=your-gemini-api-key
   ANTHROPIC_API_KEY=your-anthropic-api-key
   PORT=8000
   CORS_ORIGINS=*
   ```
6. Run the API:
   ```powershell
   python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
   ```
7. In another terminal, verify the backend is up:
   ```powershell
   Invoke-RestMethod http://127.0.0.1:8000/health
   ```

### 3. Flutter App
1. Install [Flutter SDK](https://docs.flutter.dev/get-started/install).
2. Go to the root directory `ClearLedger/`.
3. Fetch dependencies:
   ```powershell
   flutter pub get
   ```
4. Run on an Android emulator:
   ```powershell
   flutter run --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co --dart-define=SUPABASE_ANON_KEY=your-supabase-anon-key --dart-define=API_BASE_URL=http://10.0.2.2:8000
   ```
5. Run on Windows desktop:
   ```powershell
   flutter run -d windows --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co --dart-define=SUPABASE_ANON_KEY=your-supabase-anon-key --dart-define=API_BASE_URL=http://127.0.0.1:8000
   ```
6. Run on a physical Android device connected to the same network as your computer:
   ```powershell
   flutter run --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co --dart-define=SUPABASE_ANON_KEY=your-supabase-anon-key --dart-define=API_BASE_URL=http://YOUR_COMPUTER_LAN_IP:8000
   ```

If `flutter run` reports that platform folders are missing, generate them from the repo root with:

```powershell
flutter create --platforms=android,windows .
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
