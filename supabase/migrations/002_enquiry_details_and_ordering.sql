-- ==============================================================================
-- Migration 002 — Enquiry call details + insertion-order column
-- Run ONCE in the Supabase SQL Editor (safe to re-run). Run it BEFORE deploying
-- the matching API/app release.
-- ==============================================================================
BEGIN;

-- 1. Per-call details for activity 7 "Enquiries Handled".
--    number -> existing `emr` column, remarks -> existing `remarks`,
--    minutes -> existing `hours` (stored in hours), plus two new columns:
ALTER TABLE app_entries ADD COLUMN IF NOT EXISTS caller_name TEXT NOT NULL DEFAULT '';
ALTER TABLE app_entries ADD COLUMN IF NOT EXISTS call_status TEXT NOT NULL DEFAULT '';

-- 2. Strict insertion order. The app resolves "report replaced" markers by the
--    order rows were written (marker first, then its rows), which created_at
--    cannot guarantee because rows from one save share a millisecond.
ALTER TABLE app_entries ADD COLUMN IF NOT EXISTS seq BIGINT GENERATED ALWAYS AS IDENTITY;
CREATE UNIQUE INDEX IF NOT EXISTS idx_app_entries_seq ON app_entries(seq);

-- 3. Reporting views: expose the new columns and keep call-detail rows out of
--    the quantity / hours aggregates (they are a breakdown, not extra work).
CREATE OR REPLACE VIEW v_active_task_entries AS
SELECT id, created_at, uid, employee_name, date, branch, category, task_id,
       emr, remarks, quantity, hours, task_date, caller_name, call_status
FROM app_entries
WHERE task_id != '__report_replace__';

CREATE OR REPLACE VIEW v_staff_daily_workload AS
SELECT task_date, employee_name, uid, branch, category,
       COUNT(*) AS total_records,
       COALESCE(SUM(quantity), 0) AS total_quantity,
       COALESCE(SUM(hours), 0) AS total_hours
FROM v_active_task_entries
WHERE task_id NOT IN ('enquiry_detail', 'ledger_prepared', 'insurance_ledger_emr')
GROUP BY task_date, employee_name, uid, branch, category;

COMMIT;
