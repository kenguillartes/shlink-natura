# Odoo setup — QR asset tags

What connects Odoo to this Shlink deployment, and which parts are manual.
Short URLs are deterministic: `http://10.1.0.72:8080/eq-<equipment id>`.

## Already done (via MCP, 2026-07-06)

On label template **IT Asset Tag** (`zpl.label.template` ID 284, model
`maintenance.equipment`), two placeholder rows exist:

| Placeholder | Field | Transform |
|---|---|---|
| `eq_url` | ID | Prefix: `http://10.1.0.72:8080/eq-` |
| `serial` | Serial Number | — |

## Manual step 1 — paste the ZPL

Natura Print → Label Templates → **IT Asset Tag** → replace the ZPL CODE box with:

```zpl
^XA
^PW406
^LL142
^LH0,0

^FO0,4
^FB406,1,0,C,0
^A0N,20,20
^FDNATURA^FS

^FO0,26
^FB406,1,0,C,0
^A0N,18,18
^FDSN: ${serial}^FS

^FO159,48
^BQN,2,3
^FDMA,${eq_url}^FS

^XZ
```

Layout: "NATURA" / "SN: <serial>" centered on top, QR (~0.43", ECC M) centered
below on the 2.00" x 0.70" label. Check the Labelary preview for clipping;
fixes: drop the SN font to 16 or move the QR to y=46.

## Manual step 2 — read-only API key for the sync worker

1. Odoo → avatar (top right) → **My Profile** → **Account Security** tab.
2. **New API Key**, description `shlink-sync`, copy the key.
3. Put it in `/opt/shlink-natura/.env` on the VM as `ODOO_API_KEY=...`
   (plus `ODOO_DB=` — the database name from the Odoo login screen /
   database manager).

The sync worker only calls `search` on `maintenance.equipment`; a normal user
key is fine. Rotating the key later = generate a new one, update `.env`,
`make restart` (or `docker compose restart odoo_sync`).

## How new equipment gets its link

The `odoo_sync` container polls every 15 minutes and creates any missing
`eq-<id>` slug in Shlink. Force an immediate run: `make sync` on the VM.
Watch it: `make logs-sync`.
