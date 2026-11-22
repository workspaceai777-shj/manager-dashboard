# Ontario TaskLog — Supabase Migration & Database Guide

This directory contains the complete migration artifacts to convert the Ontario TaskLog database from Google Sheets to **Supabase (PostgreSQL)**.

---

## 📁 Migration Package Contents

- **`schema.sql`**: Full PostgreSQL DDL defining tables, primary keys, foreign keys, cascade rules, optimized performance indexes, Row Level Security (RLS) policies, and analytical views (`v_active_task_entries`, `v_staff_daily_workload`).
- **`seed_data.sql`**: Complete batch `INSERT` script to populate all existing users, branch assignments, normalized task catalog, and all historical task entries (~3,684 entries).
- **`data/`**: Clean CSV files ready for direct graphical import into Supabase Table Editor if preferred:
  - `data/app_users.csv`: Active staff and administrative user accounts.
  - `data/app_assignments.csv`: Branch & departmental category permissions.
  - `data/app_task_catalog.csv`: Normalized task definitions across all sections.
  - `data/app_entries.csv`: Complete historical task logs with date, quantity, hours, remarks, and EMR numbers.

---

## 🗄️ Database Architecture & Schema

### 1. `app_users`
Stores user credentials, display names, and system roles (`ADMIN` vs `STAFF`).
```sql
CREATE TABLE app_users (
    uid TEXT PRIMARY KEY,
    email TEXT NOT NULL,
    name TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'STAFF' CHECK (role IN ('ADMIN', 'STAFF')),
    active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### 2. `app_assignments`
Stores departmental categories (`FRONT DESK`, `INSURANCE USER`, `ACCOUNTS`, `DOCTOR'S ZONE`) and branch affiliations (`ONT-BR1`, `ONT-BB`) for each staff member.
```sql
CREATE TABLE app_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    uid TEXT NOT NULL REFERENCES app_users(uid) ON DELETE CASCADE,
    branch TEXT NOT NULL,
    category TEXT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (uid, branch, category)
);
```

### 3. `app_task_catalog`
Normalized catalog of activities across departments, with measurement types (`Quantity + Hours`, `Yes / No + Hours`, `AED + Hours`, `EMR Entry + Time`).
```sql
CREATE TABLE app_task_catalog (
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
```

### 4. `app_entries`
Stores individual task logs.
```sql
CREATE TABLE app_entries (
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
    task_date DATE NOT NULL
);
```

### 5. Views
- **`v_active_task_entries`**: Automatically filters out `task_id = '__report_replace__'` markers so queries only read genuine active records.
- **`v_staff_daily_workload`**: Fast aggregated view grouped by date, staff name, branch, and category.

---

## 🚀 Setup Instructions in Supabase

### Step 1: Create or Open Your Supabase Project
1. Log in to [Supabase](https://supabase.com).
2. Create a new project (e.g. `ontario-tasklog`).
3. Note your **Project URL** (e.g. `https://xyzcompany.supabase.co`) and **Service Role API Key** (`service_role` secret) found under **Project Settings > API**.

### Step 2: Run the Database Migration
1. Go to the **SQL Editor** tab in the Supabase Dashboard.
2. Click **New query**.
3. Copy and paste the contents of [`schema.sql`](file:///Users/ambikanair/FlutterDesktop/TaskLog_App/supabase/schema.sql) and click **Run**.
4. Open a second query tab, copy and paste the contents of [`seed_data.sql`](file:///Users/ambikanair/FlutterDesktop/TaskLog_App/supabase/seed_data.sql), and click **Run**.
*(Alternatively, you can import each CSV file from `supabase/data/` using the **Table Editor > Import Data from CSV**)*.

### Step 3: Connect Your Vercel API Backend
In your Vercel project settings (`tasklog-api`), add the following environment variables:
| Variable Name | Description | Example |
|---|---|---|
| `SUPABASE_URL` | Your Supabase project URL | `https://xyzcompany.supabase.co` |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase service_role secret key | `eyJhbGciOi...` |

> [!NOTE]
> **Zero-Downtime Safe Fallback**: The backend API (`repo/api/v2.js`) dynamically checks if `SUPABASE_URL` is configured. If configured, it directly reads and writes to Supabase. If not configured, it continues operating seamlessly on Google Sheets.

---

## 🔒 Security & Row Level Security (RLS)
- All tables have **Row Level Security (RLS) enabled**.
- The `service_role` key used by the Vercel API function has unrestricted backend access.
- Authenticated clients are constrained: staff can only read published catalogs, their assigned branches, and their own submissions, while administrators retain full visibility.

