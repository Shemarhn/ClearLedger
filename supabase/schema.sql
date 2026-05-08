-- ============================================================
-- ClearLedger — Full Supabase Database Schema
-- Run this in the Supabase SQL Editor in order.
-- ============================================================

-- ============================================================
-- 1. PROFILES TABLE
-- Extends auth.users with app-specific user data.
-- ============================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name   TEXT NOT NULL DEFAULT '',
    currency    TEXT NOT NULL DEFAULT 'JMD',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Users can read their own profile
CREATE POLICY "Users can view own profile"
    ON public.profiles FOR SELECT
    USING (auth.uid() = id);

-- Users can insert their own profile (trigger handles this, but policy still needed)
CREATE POLICY "Users can insert own profile"
    ON public.profiles FOR INSERT
    WITH CHECK (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Users can delete their own profile
CREATE POLICY "Users can delete own profile"
    ON public.profiles FOR DELETE
    USING (auth.uid() = id);

-- ============================================================
-- 2. AUTO-CREATE PROFILE ON SIGNUP TRIGGER
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data ->> 'full_name', '')
    );
    INSERT INTO public.accounts (user_id, name, type, is_default_cash)
    VALUES (NEW.id, 'Cash Wallet', 'cash', true)
    ON CONFLICT DO NOTHING;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- 3. TRANSACTIONS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.transactions (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    amount            NUMERIC(12,2) NOT NULL,
    merchant          TEXT,
    category          TEXT NOT NULL CHECK (category IN (
                          'Food', 'Transport', 'Utilities', 'Entertainment',
                          'Healthcare', 'Shopping', 'Education', 'Other'
                      )),
    description       TEXT,
    transaction_date  DATE NOT NULL DEFAULT CURRENT_DATE,
    input_method      TEXT NOT NULL CHECK (input_method IN ('receipt', 'text', 'manual')),
    receipt_image_url TEXT,
    raw_llm_response  JSONB,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON public.transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_date ON public.transactions(transaction_date);
CREATE INDEX IF NOT EXISTS idx_transactions_category ON public.transactions(category);

-- Money movement/account upgrade. Existing rows default to expenses.
ALTER TABLE public.transactions
    ADD COLUMN IF NOT EXISTS transaction_type TEXT NOT NULL DEFAULT 'expense'
        CHECK (transaction_type IN (
            'expense', 'income', 'transfer', 'withdrawal', 'deposit', 'refund'
        )),
    ADD COLUMN IF NOT EXISTS account_id UUID,
    ADD COLUMN IF NOT EXISTS destination_account_id UUID,
    ADD COLUMN IF NOT EXISTS card_last4 TEXT,
    ADD COLUMN IF NOT EXISTS fee_amount NUMERIC(12,2),
    ADD COLUMN IF NOT EXISTS currency TEXT NOT NULL DEFAULT 'JMD',
    ADD COLUMN IF NOT EXISTS original_amount NUMERIC(12,2),
    ADD COLUMN IF NOT EXISTS original_currency TEXT,
    ADD COLUMN IF NOT EXISTS exchange_rate NUMERIC(18,8);

CREATE INDEX IF NOT EXISTS idx_transactions_type ON public.transactions(transaction_type);
CREATE INDEX IF NOT EXISTS idx_transactions_account_id ON public.transactions(account_id);
CREATE INDEX IF NOT EXISTS idx_transactions_destination_account_id
    ON public.transactions(destination_account_id);

ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own transactions"
    ON public.transactions FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own transactions"
    ON public.transactions FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own transactions"
    ON public.transactions FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own transactions"
    ON public.transactions FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================================
-- 3B. ACCOUNTS AND CARD ROUTING
-- ============================================================
CREATE TABLE IF NOT EXISTS public.accounts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,
    type            TEXT NOT NULL CHECK (type IN (
                        'cash', 'checking', 'savings', 'credit', 'wallet', 'other'
                    )),
    currency        TEXT NOT NULL DEFAULT 'JMD',
    opening_balance NUMERIC(12,2) NOT NULL DEFAULT 0,
    is_default_cash BOOLEAN NOT NULL DEFAULT false,
    archived        BOOLEAN NOT NULL DEFAULT false,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_accounts_user_id ON public.accounts(user_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_accounts_single_default_cash
    ON public.accounts(user_id)
    WHERE is_default_cash = true AND archived = false;

ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'accounts'
        AND policyname = 'Users can view own accounts'
    ) THEN
        CREATE POLICY "Users can view own accounts"
            ON public.accounts FOR SELECT
            USING (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'accounts'
        AND policyname = 'Users can insert own accounts'
    ) THEN
        CREATE POLICY "Users can insert own accounts"
            ON public.accounts FOR INSERT
            WITH CHECK (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'accounts'
        AND policyname = 'Users can update own accounts'
    ) THEN
        CREATE POLICY "Users can update own accounts"
            ON public.accounts FOR UPDATE
            USING (auth.uid() = user_id)
            WITH CHECK (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'accounts'
        AND policyname = 'Users can delete own accounts'
    ) THEN
        CREATE POLICY "Users can delete own accounts"
            ON public.accounts FOR DELETE
            USING (auth.uid() = user_id);
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.account_card_links (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    account_id UUID NOT NULL REFERENCES public.accounts(id) ON DELETE CASCADE,
    card_last4 TEXT NOT NULL CHECK (card_last4 ~ '^[0-9]{4}$'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, card_last4)
);

CREATE INDEX IF NOT EXISTS idx_account_card_links_user_id
    ON public.account_card_links(user_id);
CREATE INDEX IF NOT EXISTS idx_account_card_links_account_id
    ON public.account_card_links(account_id);

ALTER TABLE public.account_card_links ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'account_card_links'
        AND policyname = 'Users can view own card links'
    ) THEN
        CREATE POLICY "Users can view own card links"
            ON public.account_card_links FOR SELECT
            USING (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'account_card_links'
        AND policyname = 'Users can insert own card links'
    ) THEN
        CREATE POLICY "Users can insert own card links"
            ON public.account_card_links FOR INSERT
            WITH CHECK (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'account_card_links'
        AND policyname = 'Users can update own card links'
    ) THEN
        CREATE POLICY "Users can update own card links"
            ON public.account_card_links FOR UPDATE
            USING (auth.uid() = user_id)
            WITH CHECK (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'account_card_links'
        AND policyname = 'Users can delete own card links'
    ) THEN
        CREATE POLICY "Users can delete own card links"
            ON public.account_card_links FOR DELETE
            USING (auth.uid() = user_id);
    END IF;
END $$;

INSERT INTO public.accounts (user_id, name, type, currency, is_default_cash)
SELECT
    p.id,
    'Cash Wallet',
    'cash',
    p.currency,
    NOT EXISTS (
        SELECT 1
        FROM public.accounts existing_default
        WHERE existing_default.user_id = p.id
          AND existing_default.is_default_cash = true
          AND existing_default.archived = false
    )
FROM public.profiles p
WHERE NOT EXISTS (
    SELECT 1
    FROM public.accounts existing_cash
    WHERE existing_cash.user_id = p.id
      AND existing_cash.type = 'cash'
      AND existing_cash.archived = false
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'transactions_account_id_fkey'
    ) THEN
        ALTER TABLE public.transactions
            ADD CONSTRAINT transactions_account_id_fkey
            FOREIGN KEY (account_id) REFERENCES public.accounts(id) ON DELETE SET NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'transactions_destination_account_id_fkey'
    ) THEN
        ALTER TABLE public.transactions
            ADD CONSTRAINT transactions_destination_account_id_fkey
            FOREIGN KEY (destination_account_id) REFERENCES public.accounts(id) ON DELETE SET NULL;
    END IF;
END $$;

-- ============================================================
-- 4. BUDGETS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.budgets (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    category      TEXT NOT NULL CHECK (category IN (
                      'Food', 'Transport', 'Utilities', 'Entertainment',
                      'Healthcare', 'Shopping', 'Education', 'Other'
                  )),
    monthly_limit NUMERIC(12,2) NOT NULL CHECK (monthly_limit > 0),
    month         DATE NOT NULL, -- first day of the month this budget applies to
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, category, month)
);

CREATE INDEX IF NOT EXISTS idx_budgets_user_id ON public.budgets(user_id);

ALTER TABLE public.budgets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own budgets"
    ON public.budgets FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own budgets"
    ON public.budgets FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own budgets"
    ON public.budgets FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own budgets"
    ON public.budgets FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================================
-- 5. FCM TOKENS TABLE
-- ============================================================
CREATE TABLE IF NOT EXISTS public.fcm_tokens (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    token      TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, token)
);

ALTER TABLE public.fcm_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own fcm tokens"
    ON public.fcm_tokens FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own fcm tokens"
    ON public.fcm_tokens FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own fcm tokens"
    ON public.fcm_tokens FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own fcm tokens"
    ON public.fcm_tokens FOR DELETE
    USING (auth.uid() = user_id);

-- ============================================================
-- 6. STORAGE BUCKET FOR RECEIPTS
-- Run this to create the receipts bucket.
-- Then add a storage policy in the Supabase dashboard or via SQL:
-- ============================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('receipts', 'receipts', false)
ON CONFLICT (id) DO NOTHING;

-- Storage policy: users can only access their own folder
CREATE POLICY "Users can upload own receipts"
    ON storage.objects FOR INSERT
    WITH CHECK (
        bucket_id = 'receipts'
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can view own receipts"
    ON storage.objects FOR SELECT
    USING (
        bucket_id = 'receipts'
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

CREATE POLICY "Users can delete own receipts"
    ON storage.objects FOR DELETE
    USING (
        bucket_id = 'receipts'
        AND auth.uid()::text = (storage.foldername(name))[1]
    );

-- ============================================================
-- 7. SERVICE ROLE POLICY (for FastAPI backend access)
-- The service role key bypasses RLS, but this makes it explicit.
-- ============================================================
-- FastAPI uses the service_role key which bypasses RLS.
-- No additional policies needed for backend access.

-- Make PostgREST pick up any newly added columns immediately after running this script.
NOTIFY pgrst, 'reload schema';
