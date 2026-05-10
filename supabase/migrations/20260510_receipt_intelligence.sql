-- ============================================================
-- Receipt intelligence feedback loop
-- Stores every parse outcome and learns user-confirmed merchant preferences.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.receipt_parse_events (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id              UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    input_method         TEXT NOT NULL DEFAULT 'receipt'
                         CHECK (input_method IN ('receipt', 'text', 'manual')),
    ocr_text             TEXT,
    receipt_image_url    TEXT,
    receipt_image_path   TEXT,
    parser_candidates    JSONB NOT NULL DEFAULT '{}'::jsonb,
    parsed_payload       JSONB NOT NULL DEFAULT '{}'::jsonb,
    raw_llm_response     JSONB NOT NULL DEFAULT '{}'::jsonb,
    model_source         TEXT,
    confidence           NUMERIC(5,4),
    status               TEXT NOT NULL DEFAULT 'parsed'
                         CHECK (status IN ('parsed', 'saved', 'corrected', 'cancelled')),
    final_transaction_id UUID REFERENCES public.transactions(id) ON DELETE SET NULL,
    final_payload        JSONB,
    correction_summary   JSONB NOT NULL DEFAULT '{}'::jsonb,
    cancel_reason        TEXT,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_receipt_parse_events_user_id
    ON public.receipt_parse_events(user_id);
CREATE INDEX IF NOT EXISTS idx_receipt_parse_events_status
    ON public.receipt_parse_events(status);
CREATE INDEX IF NOT EXISTS idx_receipt_parse_events_created_at
    ON public.receipt_parse_events(created_at DESC);

ALTER TABLE public.receipt_parse_events ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'receipt_parse_events'
        AND policyname = 'Users can view own receipt parse events'
    ) THEN
        CREATE POLICY "Users can view own receipt parse events"
            ON public.receipt_parse_events FOR SELECT
            USING (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'receipt_parse_events'
        AND policyname = 'Users can insert own receipt parse events'
    ) THEN
        CREATE POLICY "Users can insert own receipt parse events"
            ON public.receipt_parse_events FOR INSERT
            WITH CHECK (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'receipt_parse_events'
        AND policyname = 'Users can update own receipt parse events'
    ) THEN
        CREATE POLICY "Users can update own receipt parse events"
            ON public.receipt_parse_events FOR UPDATE
            USING (auth.uid() = user_id)
            WITH CHECK (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'receipt_parse_events'
        AND policyname = 'Users can delete own receipt parse events'
    ) THEN
        CREATE POLICY "Users can delete own receipt parse events"
            ON public.receipt_parse_events FOR DELETE
            USING (auth.uid() = user_id);
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.receipt_merchant_memory (
    id                               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                          UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    merchant_key                     TEXT NOT NULL,
    merchant_display                 TEXT NOT NULL,
    preferred_category               TEXT CHECK (
                                         preferred_category IS NULL OR preferred_category IN (
                                             'Food', 'Transport', 'Utilities', 'Entertainment',
                                             'Healthcare', 'Shopping', 'Education', 'Other'
                                         )
                                     ),
    preferred_transaction_type       TEXT CHECK (
                                         preferred_transaction_type IS NULL OR preferred_transaction_type IN (
                                             'expense', 'income', 'transfer', 'withdrawal', 'deposit', 'refund'
                                         )
                                     ),
    preferred_currency               TEXT,
    preferred_account_id             UUID REFERENCES public.accounts(id) ON DELETE SET NULL,
    preferred_destination_account_id UUID REFERENCES public.accounts(id) ON DELETE SET NULL,
    last_card_last4                  TEXT,
    usage_count                      INTEGER NOT NULL DEFAULT 0,
    confirmed_count                  INTEGER NOT NULL DEFAULT 0,
    corrected_count                  INTEGER NOT NULL DEFAULT 0,
    first_seen_at                    TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen_at                     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                       TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, merchant_key)
);

CREATE INDEX IF NOT EXISTS idx_receipt_merchant_memory_user_id
    ON public.receipt_merchant_memory(user_id);
CREATE INDEX IF NOT EXISTS idx_receipt_merchant_memory_key
    ON public.receipt_merchant_memory(user_id, merchant_key);

ALTER TABLE public.receipt_merchant_memory ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'receipt_merchant_memory'
        AND policyname = 'Users can view own receipt merchant memory'
    ) THEN
        CREATE POLICY "Users can view own receipt merchant memory"
            ON public.receipt_merchant_memory FOR SELECT
            USING (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'receipt_merchant_memory'
        AND policyname = 'Users can insert own receipt merchant memory'
    ) THEN
        CREATE POLICY "Users can insert own receipt merchant memory"
            ON public.receipt_merchant_memory FOR INSERT
            WITH CHECK (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'receipt_merchant_memory'
        AND policyname = 'Users can update own receipt merchant memory'
    ) THEN
        CREATE POLICY "Users can update own receipt merchant memory"
            ON public.receipt_merchant_memory FOR UPDATE
            USING (auth.uid() = user_id)
            WITH CHECK (auth.uid() = user_id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'receipt_merchant_memory'
        AND policyname = 'Users can delete own receipt merchant memory'
    ) THEN
        CREATE POLICY "Users can delete own receipt merchant memory"
            ON public.receipt_merchant_memory FOR DELETE
            USING (auth.uid() = user_id);
    END IF;
END $$;

NOTIFY pgrst, 'reload schema';
