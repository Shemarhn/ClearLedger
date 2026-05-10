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
