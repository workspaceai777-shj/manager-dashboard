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

// PostgREST caps a single response (Supabase default: 1000 rows).
// We request exact count on the first page and fetch any remaining pages
// concurrently with Promise.all for maximum throughput.
const PAGE_SIZE = 1000;
export async function readSupabaseTable(table, queryParams = '') {
  const url = `${getBaseUrl()}/rest/v1/${table}${queryParams ? `?${queryParams}` : ''}`;
  const baseHeaders = {
    ...getHeaders(),
    'Accept-Encoding': 'gzip, deflate, br',
    'Range-Unit': 'items',
  };

  // Fetch the first page with count=exact to discover total rows
  const firstRes = await fetch(url, {
    method: 'GET',
    headers: { ...baseHeaders, Range: `0-${PAGE_SIZE - 1}`, Prefer: 'count=exact' },
  });
  if (!firstRes.ok) {
    const errorText = await firstRes.text();
    throw new Error(`Supabase GET ${table} failed (${firstRes.status}): ${errorText}`);
  }

  const firstPage = await firstRes.json();
  const all = [...firstPage];

  // If there are more items, parse the Content-Range header: e.g. "0-999/6438"
  const contentRange = firstRes.headers.get('content-range') || '';
  const match = contentRange.match(/\/(\d+)$/);
  const total = match ? parseInt(match[1], 10) : (firstPage.length < PAGE_SIZE ? firstPage.length : null);

  if (firstPage.length === PAGE_SIZE && total && total > PAGE_SIZE) {
    const pagePromises = [];
    for (let from = PAGE_SIZE; from < total; from += PAGE_SIZE) {
      const to = Math.min(from + PAGE_SIZE - 1, total - 1);
      pagePromises.push(
        fetch(url, {
          method: 'GET',
          headers: { ...baseHeaders, Range: `${from}-${to}` },
        }).then(async (r) => {
          if (!r.ok) {
            const err = await r.text();
            throw new Error(`Supabase GET ${table} page ${from}-${to} failed (${r.status}): ${err}`);
          }
          return r.json();
        })
      );
    }
    const remainingPages = await Promise.all(pagePromises);
    for (const page of remainingPages) {
      all.push(...page);
    }
  } else if (!total && firstPage.length === PAGE_SIZE) {
    // Fallback if total count could not be determined
    for (let from = PAGE_SIZE; ; from += PAGE_SIZE) {
      const res = await fetch(url, {
        method: 'GET',
        headers: { ...baseHeaders, Range: `${from}-${from + PAGE_SIZE - 1}` },
      });
      if (!res.ok) {
        const errorText = await res.text();
        throw new Error(`Supabase GET ${table} failed (${res.status}): ${errorText}`);
      }
      const page = await res.json();
      all.push(...page);
      if (page.length < PAGE_SIZE) break;
    }
  }

  return all;
}

const NOT_NULL_EMPTY_COLS = new Set(['caller_name', 'call_status', 'caller_phone', 'emr', 'remarks']);

export async function insertSupabaseRows(table, rows, upsert = false, returnMinimal = false) {
  if (!rows || rows.length === 0) return [];
  // PostgREST requires all objects in a bulk insert array to have identical keys (PGRST102).
  let payload = rows;
  if (rows.length > 1) {
    const allKeys = Array.from(new Set(rows.flatMap((r) => Object.keys(r))));
    payload = rows.map((r) => {
      const normalized = {};
      for (const k of allKeys) {
        normalized[k] = r[k] !== undefined ? r[k] : (NOT_NULL_EMPTY_COLS.has(k) ? '' : null);
      }
      return normalized;
    });
  }
  const url = `${getBaseUrl()}/rest/v1/${table}`;
  const headers = getHeaders();
  if (upsert) {
    headers['Prefer'] = returnMinimal
      ? 'resolution=merge-duplicates,return=minimal'
      : 'resolution=merge-duplicates,return=representation';
  } else if (returnMinimal) {
    headers['Prefer'] = 'return=minimal';
  }
  const res = await fetch(url, {
    method: 'POST',
    headers,
    body: JSON.stringify(payload),
  });
  if (!res.ok) {
    const errorText = await res.text();
    throw new Error(`Supabase POST ${table} failed (${res.status}): ${errorText}`);
  }
  if (returnMinimal || res.status === 204) return [];
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

