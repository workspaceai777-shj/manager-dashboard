/**
 * Supabase Data Client for Ontario TaskLog Backend
 * Provides native PostgREST data access using global fetch().
 * Requires environment variables:
 * - SUPABASE_URL: e.g. https://xyzcompany.supabase.co
 * - SUPABASE_SERVICE_ROLE_KEY: service_role secret key for administrative backend access
 */

export function isSupabaseConfigured() {
  return Boolean(process.env.SUPABASE_URL && process.env.SUPABASE_SERVICE_ROLE_KEY);
}

function getHeaders() {
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  return {
    apikey: key,
    Authorization: `Bearer ${key}`,
    'Content-Type': 'application/json',
    Prefer: 'return=representation',
  };
}

function getBaseUrl() {
  return (process.env.SUPABASE_URL || '').replace(/\/+$/, '');
}

export async function readSupabaseTable(table, queryParams = '') {
  const url = `${getBaseUrl()}/rest/v1/${table}${queryParams ? `?${queryParams}` : ''}`;
  const res = await fetch(url, {
    method: 'GET',
    headers: getHeaders(),
  });
  if (!res.ok) {
    const errorText = await res.text();
    throw new Error(`Supabase GET ${table} failed (${res.status}): ${errorText}`);
  }
  return await res.json();
}

export async function insertSupabaseRows(table, rows, upsert = false) {
  if (!rows || rows.length === 0) return [];
  const url = `${getBaseUrl()}/rest/v1/${table}`;
  const headers = getHeaders();
  if (upsert) {
    headers['Prefer'] = 'resolution=merge-duplicates,return=representation';
  }
  const res = await fetch(url, {
    method: 'POST',
    headers,
    body: JSON.stringify(rows),
  });
  if (!res.ok) {
    const errorText = await res.text();
    throw new Error(`Supabase POST ${table} failed (${res.status}): ${errorText}`);
  }
  return await res.json();
}

export async function deleteSupabaseRows(table, queryParams) {
  const url = `${getBaseUrl()}/rest/v1/${table}?${queryParams}`;
  const res = await fetch(url, {
    method: 'DELETE',
    headers: getHeaders(),
  });
  if (!res.ok) {
    const errorText = await res.text();
    throw new Error(`Supabase DELETE ${table} failed (${res.status}): ${errorText}`);
  }
  return true;
}

export async function patchSupabaseRows(table, queryParams, updates) {
  const url = `${getBaseUrl()}/rest/v1/${table}?${queryParams}`;
  const res = await fetch(url, {
    method: 'PATCH',
    headers: getHeaders(),
    body: JSON.stringify(updates),
  });
  if (!res.ok) {
    const errorText = await res.text();
    throw new Error(`Supabase PATCH ${table} failed (${res.status}): ${errorText}`);
  }
  return await res.json();
}

