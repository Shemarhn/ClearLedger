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
3. Ensure the `receipts` storage bucket is set up.

### 2. FastAPI Backend
1. Go to the `backend/` directory.
2. Ensure you have Python 3.10+ installed.
3. Install dependencies:
   ```bash
   python -m venv venv
   source venv/bin/activate  # Or `.\venv\Scripts\activate` on Windows
   pip install -r requirements.txt
   ```
4. Create a `.env` file based on `.env.example` (or set them manually) with:
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `SUPABASE_JWT_SECRET`
   - `GEMINI_API_KEY`
   - `ANTHROPIC_API_KEY`
5. Run the server locally:
   ```bash
   uvicorn main:app --reload
   ```
6. **Deploy to Railway:** Connect the repository to Railway, set the root directory to `backend/`, and provide the environment variables.

### 3. Flutter App
1. Install [Flutter SDK](https://docs.flutter.dev/get-started/install).
2. Go to the root directory `ClearLedger/`.
3. Fetch dependencies:
   ```bash
   flutter pub get
   ```
4. Update `lib/core/constants.dart` with your Supabase URL, Anon Key, and the FastAPI base URL.
5. Run the app:
   ```bash
   flutter run
   ```

## Workflow & Safety
- **Review Transaction Screen:** Ensures human-in-the-loop review of AI-parsed data. The user confirms or corrects details before storing in the database.
- **Row-Level Security (RLS):** Enforced at the Supabase PostgreSQL level.