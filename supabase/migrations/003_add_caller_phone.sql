-- ==============================================================================
-- Migration 003 — Optional caller phone for enquiry_detail rows
-- Additive and idempotent (safe to re-run). Nullable, no default: no table
-- rewrite. Run BEFORE deploying the matching API/app release.
-- Rollback: ALTER TABLE app_entries DROP CONSTRAINT IF EXISTS chk_app_entries_caller_phone_len;
--           ALTER TABLE app_entries DROP COLUMN IF EXISTS caller_phone;
-- ==============================================================================
BEGIN;

ALTER TABLE app_entries ADD COLUMN IF NOT EXISTS caller_phone TEXT;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_app_entries_caller_phone_len'
          AND conrelid = 'app_entries'::regclass
    ) THEN
        ALTER TABLE app_entries
            ADD CONSTRAINT chk_app_entries_caller_phone_len
            CHECK (caller_phone IS NULL OR char_length(caller_phone) <= 30);
    END IF;
END $$;

COMMIT;
