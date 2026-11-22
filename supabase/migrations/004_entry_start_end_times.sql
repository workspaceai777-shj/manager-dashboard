-- ==============================================================================
-- Migration 004 — Optional start/end times for entries
-- Used by task_id 'enquiry_detail' (activity 7 calls) and
-- 'ledger_prepared' / 'insurance_ledger_emr' rows.
-- Additive and idempotent (safe to re-run). Nullable, no default: no table
-- rewrite. Run BEFORE deploying the matching API/app release.
-- View v_active_task_entries is replaced with the two new columns appended at
-- the END (existing column order preserved). v_staff_daily_workload unchanged.
-- Rollback (view first, since it depends on the columns):
--   CREATE OR REPLACE VIEW v_active_task_entries AS
--     SELECT id, created_at, uid, employee_name, date, branch, category, task_id,
--            emr, remarks, quantity, hours, task_date, caller_name, call_status
--     FROM app_entries WHERE task_id != '__report_replace__';
--   (CREATE OR REPLACE cannot drop columns; if it errors, DROP VIEW
--    v_staff_daily_workload, v_active_task_entries and recreate both from
--    schema.sql minus the new columns.)
--   ALTER TABLE app_entries DROP CONSTRAINT IF EXISTS chk_app_entries_time_order;
--   ALTER TABLE app_entries DROP COLUMN IF EXISTS end_time;
--   ALTER TABLE app_entries DROP COLUMN IF EXISTS start_time;
-- ==============================================================================
BEGIN;

ALTER TABLE app_entries ADD COLUMN IF NOT EXISTS start_time TIMESTAMPTZ;
ALTER TABLE app_entries ADD COLUMN IF NOT EXISTS end_time TIMESTAMPTZ;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'chk_app_entries_time_order'
          AND conrelid = 'app_entries'::regclass
    ) THEN
        ALTER TABLE app_entries
            ADD CONSTRAINT chk_app_entries_time_order
            CHECK (end_time IS NULL OR start_time IS NULL OR end_time >= start_time);
    END IF;
END $$;

CREATE OR REPLACE VIEW v_active_task_entries AS
SELECT
    id,
    created_at,
    uid,
    employee_name,
    date,
    branch,
    category,
    task_id,
    emr,
    remarks,
    quantity,
    hours,
    task_date,
    caller_name,
    call_status,
    start_time,
    end_time
FROM app_entries
WHERE task_id != '__report_replace__';

COMMIT;
