# Handoff — Shlink asset-tag system & next project (cultivation tables)

Last updated: 2026-07-07. Author: Claude session with Kenny (kenny.g@natura.io).

## What exists and works (verified end to end)

- **Shlink URL shortener** on Proxmox VM 113 "shlink" — Alpine Linux, static IP
  `10.1.0.72` (Kea DHCP static mapping, MAC BA:B0:D6:61:C5:24), auto-starts on boot.
- Stack lives in `/opt/shlink-natura` on the VM, running branch `feat/qr-asset-tags`
  of `github.com/kenguillartes/shlink-natura`. Containers:
  - `shlink` — :8080, redirects + REST API
  - `shlink_db` (MariaDB 11), `shlink_redis`
  - `shlink_web_client` — admin UI, internal-only
  - `shlink_web_auth` — nginx basic-auth gate publishing the UI on :8081
    (users managed via `sh deploy/set-webui-password.sh <name>`; file `deploy/htpasswd`, not in git)
  - `shlink_odoo_sync` — every 15 min creates slug `eq-<id>` for each active
    `maintenance.equipment` record in Odoo → redirects to the equipment form
- **Verified:** `curl -I http://10.1.0.72:8080/eq-118` → 302 to the Odoo equipment URL.
- **Odoo side** (db `naturaprod17db`, Odoo 17.0+e): label template `zpl.label.template`
  ID 284 "IT Asset Tag" with placeholders `eq_url` (id + Prefix `http://10.1.0.72:8080/eq-`)
  and `serial` (serial_no). Final ZPL: black full-width banner + white Natura logo (GFA
  bitmap) + NATURA wordmark, centered QR (`^BQN,2,3`, ECC M), serial under it.
  2×1" @ 203 dpi (`^PW406 ^LL203`). Label Height field on the template must be 1.00.

## Pending / operational notes

- Uline "Industrial Weatherproof Thermal Transfer, Polypropylene, 2 × 1" labels +
  wax-resin ribbon → print on **ZT411 (203 dpi)**. Start darkness ~15, speed 4 ips.
- New-employee flow: create equipment record → template "Update Preview" → pick
  record + printer → Print. Sync makes the QR resolve within 15 min (`make sync` forces).
- Desk scanner recommendation: 2D imager, USB HID (e.g. Zebra DS2208 in presentation mode).
- `.env` on the VM has stale duplicate lines (last value wins) — harmless; cleanup optional.
- Branch `feat/qr-asset-tags` not yet merged to `develop`.

## Environment quirks (will bite you if forgotten)

- Odoo production DB is **naturaprod17db** — NOT `natura17db` (that's a stale sibling;
  `/var/odoo/natura17db/` in tracebacks is just the install dir).
- Natura MCP: `create_record` allowed, `update_record` blanket-denied — ZPL/template
  edits must be done by Kenny in the UI; placeholder rows can be created via MCP.
- Proxmox noVNC console mangles synthetic keystrokes (underscore→dash, `&&`→`77`).
  Use SSH (`kenny@10.1.0.72`, then `su -`) or ship scripts via the repo + `wget raw.githubusercontent.com/...`.
- Labelary previews (also used for repo-side rendering):
  `POST http://api.labelary.com/v1/printers/8dpmm/labels/2x1/0/`.

## Next project: QR codes for cultivation tables (SEPARATE from Odoo)

Status: **not designed yet — brainstorm with Kenny before building anything.**

Known so far (2026-07-07):
- Tables are tracked in a **Google Sheet**, serialized numerically (1800, 1801, …).
- Stickers are printed from the Sheet itself; a QR image column uses
  `=IMAGE("https://image-charts.com/chart?chs=300x300&cht=qr&choe=UTF-8&chl="&ENCODEURL(D<row>))`
  (if cells show #REF!, click the "Allow access" popup — external-fetch permission).
- Explicitly **not** tied to Odoo — no equipment records, no odoo_sync involvement.
- **Undecided: where a scanned table QR should land.** That's the brainstorm.
  Candidates floated: static info page, dashboard, sheet row, Metrc view.

Constraints/recommendations already established:
- Google's `IMAGE()` fetches from Google servers → it **cannot** reach LAN-only
  `10.1.0.72`, so Shlink's own `/qr-code` endpoint won't render inside Sheets.
  Keep image-charts.com for the QR *image*; make the QR *content* (column D) a
  Shlink short URL like `http://10.1.0.72:8080/table-1800`.
- Routing through Shlink means stickers never need reprinting — re-point any
  table's destination with a PATCH; also gives per-table scan stats.
- Bulk slug creation: clone the POST-and-skip pattern from `sync/sync.py`
  (one-shot script reading serials from the Sheet/CSV, tag `cultivation-table`).

### Shlink API primer (what the next session needs)

- Base: `http://10.1.0.72:8080/rest/v3/` — full docs at https://api-spec.shlink.io
  (OpenAPI) and https://shlink.io/documentation/api-docs/.
- Auth: header `X-Api-Key: <key>` — key lives on the VM in `/opt/shlink-natura/.env`
  (`SHLINK_API_KEY=`). New keys: `make api-key` on the VM.
- Create short URL: `POST /rest/v3/short-urls` JSON body:
  `{"longUrl": "...", "customSlug": "table-01", "tags": ["cultivation-table"], "findIfExists": false}`
  → 400 with type `https://shlink.io/api/error/non-unique-slug` if slug taken (idempotency check).
- Edit redirect target later: `PATCH /rest/v3/short-urls/{shortCode}` with `{"longUrl": "..."}`
  — useful: table QR can be printed once and re-pointed anytime.
- List/filter: `GET /rest/v3/short-urls?tags[]=cultivation-table&itemsPerPage=100`.
- Visit stats: `GET /rest/v3/short-urls/{shortCode}/visits`.
- QR code endpoint — Shlink generates QR PNGs natively, no API key needed:
  `GET http://10.1.0.72:8080/{shortCode}/qr-code?size=300&format=png&errorCorrection=M`
  (handy for cultivation tables if labels won't come from the ZPL/Zebra pipeline).
- Suggested slug convention: `table-<something stable>` — keep the eq- prefix reserved
  for equipment. Tag everything (`cultivation-table`) so lists/stats stay separable.

### Existing pieces reusable for tables

- The sync worker pattern (`sync/sync.py`) — stdlib-only Python, POST-and-skip
  idempotency; easy to clone for a table list from any source (CSV, sheet, API).
- `deploy/export-labels-csv.sh` — pattern for generating merge-print CSVs.
- The ZPL banner/QR label design (template 284's code) if tables get Zebra labels too.
