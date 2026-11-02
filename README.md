# Clinic Staff Manager Dashboard — Vercel + Google Sheets

A responsive **read-only** manager dashboard for the 21-task `createClinicDailyReportV2` Google Form. Displays quantity, task hours, reported working hours, collections, ledger-only targets, staff comparisons, daily trends, and data quality warnings. No Google Sheet edits occur.

## Deployment (Vercel)

1. Create a Google Cloud project, enable **Google Sheets API**, and create a **service account**. Create and download a JSON private key for that service account. Never commit the JSON file to your repo or put it in `public/`.
2. Open the actual V2 Google Sheet: `https://docs.google.com/spreadsheets/d/1Zr7W7P7JUTUR43nDmR1YWmvqYsdctdzmMfM7Px-q7lo/edit`. Click **Share** and grant the service account's `client_email` **Viewer** access. This does not make the sheet public.
3. Upload the *contents* of this project folder to a **private GitHub repository** (recommended), then import it in Vercel as a new project. Framework preset **Other**; no build command is needed. You may also deploy through Vercel CLI.
4. In Vercel Project → **Settings → Environment Variables**, add:

   | Name | Value |
   |---|---|
   | `GOOGLE_SHEET_ID` | `1Zr7W7P7JUTUR43nDmR1YWmvqYsdctdzmMfM7Px-q7lo` |
   | `GOOGLE_SERVICE_ACCOUNT_EMAIL` | JSON `client_email` from the service account |
   | `GOOGLE_PRIVATE_KEY` | JSON `private_key` including `-----BEGIN PRIVATE KEY-----` / `-----END PRIVATE KEY-----`, with actual line breaks or literal `\n` |
   | `DASHBOARD_PASSWORD` | Strong unique password for manager access |
   | `RESPONSES_TAB` | Optional: exact Google Sheet response tab name, e.g., `Form Responses 1` |
   | `DATE_FORMAT` | `DMY` (default). Use `MDY` only if the response date strings are month/day/year. |

5. **Redeploy** after adding environment variables. Visit the Vercel URL, enter `DASHBOARD_PASSWORD`, and set the relevant reporting dates.

**Security:** The service account private key is used only by `/api/report.js` on Vercel's server; it is never sent to the browser. Use a private repo, a strong password, and do not embed service account credentials in any HTML or frontend JavaScript. The shared manager password provides basic access protection; for multiple managers or sensitive patient data, replace it with proper user authentication and access logs. This system reads only aggregated staff task data, not patient identifiers.

## Ledger targets

Only these two tasks are targeted:
- `Ledgers Prepared (New, convert from R3 to R4)`
- `Ledgers Updated (updating the R4 format)`

Defaults in `api/report.js`:

| Employee | Prepared per reported day | Updated per reported day |
|---|---:|---:|
| Prince | 6 | 15 |
| Farsana | 5 | 0 |
| Stanly | 0 | 18 |

Edit `TARGETS` in `api/report.js` to adjust. The target for the selected period = sum of per-day targets × **distinct reported days**, not every calendar day. Because no attendance roster was supplied, days without submissions are not assumed to be missed shifts. For a staff member assigned both tasks, combined ledger achievement = total prepared + updated, divided by total combined target. Percentages are not capped.

## Data handling and assumptions

- Detects the response tab from the headers (`Employee Name`, `Reporting Date`); optionally pin with `RESPONSES_TAB`.
- Reads the latest (last row) response per employee + reporting date when duplicates exist, and flags exclusions. Google Forms typically appends rows chronologically.
- Form quantity and hours are mapped by **exact question titles**, not column order.
- `Daily Collection (AED)` is treated as money, not a unit count. Its hours are included in task hours.
- Hours are decimal: `1.5` means 1 hour 30 minutes.
- Form-entered `Total Working Hours` is compared with the sum of task hours; mismatches over 0.25 hour are flagged.
- Productivity is task quantity / task hours. Minute-per-ledger uses only hours reported for the two ledger tasks.
- All 21 activities can be browsed in the detail table; neither the raw form data nor any sensitive credentials are exposed in HTML source.
- Date filters default to the current browser month. Choose the month with actual submissions if dashboard initially shows zero.
- Up to 20,000 response rows are requested from Google Sheets. Increase API range if needed.

## Run locally

Install Vercel CLI (`npm i -g vercel`), link the project with `vercel link`, pull env variables with `vercel env pull .env.local`, then run `vercel dev`. Avoid sharing `.env.local`.

## Files

- `public/index.html` — UI
- `public/style.css` — responsive styling
- `public/app.js` — browser-side visualization
- `api/report.js` — serverless Google Sheets reader, calculations, password check
- `vercel.json` — static rewrites

## Troubleshooting

- `401 Invalid dashboard password`: check `DASHBOARD_PASSWORD` and enter the same value in the login form.
- `500 Unable to read Google Sheets`: check service account email/private key and share the Sheet as Viewer with the service account; check Sheets API enabled and project logs.
- `Form response tab not found`: check tab headers or set `RESPONSES_TAB` to its exact title.
- Unexpected reporting dates: set `DATE_FORMAT` to match the Google Sheets formatted date locale.
- Empty reports: date filter may not include submission dates, or the V2 form has not received submissions.
