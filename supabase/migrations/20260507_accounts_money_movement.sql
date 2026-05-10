-- ClearLedger account and money-movement upgrade.
-- Run this against an existing ClearLedger Supabase project.

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
    )
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.accounts (user_id, name, type, is_default_cash)
    VALUES (NEW.id, 'Cash Wallet', 'cash', true)
    ON CONFLICT DO NOTHING;

    RETURN NEW;
END;
$$;

-- Make PostgREST pick up the newly added transaction/account columns immediately.
NOTIFY pgrst, 'reload schema';
