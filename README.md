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
