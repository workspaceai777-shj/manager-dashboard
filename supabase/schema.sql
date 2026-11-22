-- ==============================================================================
-- Ontario Staff Task Database - PostgreSQL / Supabase Schema
-- ==============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ------------------------------------------------------------------------------
-- 1. app_users: Application user accounts and authorization roles
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS app_users (
    uid TEXT PRIMARY KEY,
    email TEXT NOT NULL,
    name TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'STAFF' CHECK (role IN ('ADMIN', 'STAFF')),
    active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------------------------
-- 2. app_assignments: Staff branch & departmental category assignments
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS app_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    uid TEXT NOT NULL REFERENCES app_users(uid) ON DELETE CASCADE,
    branch TEXT NOT NULL,
    category TEXT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (uid, branch, category)
);

-- ------------------------------------------------------------------------------
-- 3. app_task_catalog: Normalized task definitions across branches & sections
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS app_task_catalog (
    id TEXT PRIMARY KEY,
    section TEXT NOT NULL,
    category TEXT NOT NULL,
    branch TEXT NOT NULL DEFAULT 'ALL',
    name TEXT NOT NULL,
    measurement TEXT NOT NULL DEFAULT 'Quantity + Hours',
    display_order INT NOT NULL DEFAULT 0,
    active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------------------------
-- 4. app_entries: Historical and daily task activity logs
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS app_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    uid TEXT NOT NULL REFERENCES app_users(uid) ON DELETE CASCADE,
    employee_name TEXT NOT NULL,
    date DATE NOT NULL,
    branch TEXT NOT NULL,
    category TEXT NOT NULL,
    task_id TEXT NOT NULL,
    emr TEXT DEFAULT '',
    remarks TEXT DEFAULT '',
    quantity NUMERIC(10, 2) DEFAULT 0,
    hours NUMERIC(10, 2) DEFAULT 0,
    task_date DATE NOT NULL,
    -- Enquiry call details (activity 7); see migrations/002
    caller_name TEXT NOT NULL DEFAULT '',
    call_status TEXT NOT NULL DEFAULT '',
    -- Optional caller phone; see migrations/003
    caller_phone TEXT CONSTRAINT chk_app_entries_caller_phone_len CHECK (caller_phone IS NULL OR char_length(caller_phone) <= 30),
    -- Optional start/end times; see migrations/004
    start_time TIMESTAMPTZ,
    end_time TIMESTAMPTZ,
    CONSTRAINT chk_app_entries_time_order CHECK (end_time IS NULL OR start_time IS NULL OR end_time >= start_time),
    -- Strict insertion order, used to resolve "report replaced" markers
    seq BIGINT GENERATED ALWAYS AS IDENTITY
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_app_entries_seq ON app_entries(seq);

-- ------------------------------------------------------------------------------
-- Performance Indexes for Real-time Dashboard & Historical Analytics
-- ------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_app_entries_task_date ON app_entries(task_date);
CREATE INDEX IF NOT EXISTS idx_app_entries_uid_task_date ON app_entries(uid, task_date);
CREATE INDEX IF NOT EXISTS idx_app_entries_branch_category ON app_entries(branch, category);
CREATE INDEX IF NOT EXISTS idx_app_entries_task_id ON app_entries(task_id);
CREATE INDEX IF NOT EXISTS idx_app_entries_created_at ON app_entries(created_at);
CREATE INDEX IF NOT EXISTS idx_app_assignments_uid ON app_assignments(uid);

-- ------------------------------------------------------------------------------
-- View: v_active_task_entries
-- Excludes '__report_replace__' overwrite ledger markers to present active entries
-- ------------------------------------------------------------------------------
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

-- ------------------------------------------------------------------------------
-- View: v_staff_daily_workload
-- Aggregated daily summary per employee, date, branch, and category
-- ------------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_staff_daily_workload AS
SELECT 
    task_date,
    employee_name,
    uid,
    branch,
    category,
    COUNT(*) AS total_records,
    COALESCE(SUM(quantity), 0) AS total_quantity,
    COALESCE(SUM(hours), 0) AS total_hours
FROM v_active_task_entries
WHERE task_id NOT IN ('enquiry_detail', 'ledger_prepared', 'insurance_ledger_emr')
GROUP BY task_date, employee_name, uid, branch, category;

-- ------------------------------------------------------------------------------
-- Row Level Security (RLS) Policies
-- ------------------------------------------------------------------------------
ALTER TABLE app_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_task_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_entries ENABLE ROW LEVEL SECURITY;

-- Service role bypass (full administrative access for backend serverless functions)
DROP POLICY IF EXISTS "service_role_full_access_users" ON app_users;
CREATE POLICY "service_role_full_access_users" ON app_users FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "service_role_full_access_assignments" ON app_assignments;
CREATE POLICY "service_role_full_access_assignments" ON app_assignments FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "service_role_full_access_catalog" ON app_task_catalog;
CREATE POLICY "service_role_full_access_catalog" ON app_task_catalog FOR ALL TO service_role USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "service_role_full_access_entries" ON app_entries;
CREATE POLICY "service_role_full_access_entries" ON app_entries FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Authenticated users policies
DROP POLICY IF EXISTS "authenticated_read_users" ON app_users;
CREATE POLICY "authenticated_read_users" ON app_users FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "authenticated_read_catalog" ON app_task_catalog;
CREATE POLICY "authenticated_read_catalog" ON app_task_catalog FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "authenticated_read_assignments" ON app_assignments;
CREATE POLICY "authenticated_read_assignments" ON app_assignments FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "authenticated_read_entries" ON app_entries;
CREATE POLICY "authenticated_read_entries" ON app_entries FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "authenticated_insert_entries" ON app_entries;
CREATE POLICY "authenticated_insert_entries" ON app_entries FOR INSERT TO authenticated WITH CHECK (auth.uid()::text = uid OR EXISTS (SELECT 1 FROM app_users WHERE uid = auth.uid()::text AND role = 'ADMIN'));
