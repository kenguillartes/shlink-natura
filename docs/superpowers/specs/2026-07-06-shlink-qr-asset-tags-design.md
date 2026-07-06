# Shlink QR Asset Tags — Design

**Date:** 2026-07-06
**Status:** Approved by Kenny (pending spec review)

## Goal

Print QR codes on IT asset tags (Natura Print module in Odoo) that redirect to the
equipment's record in Odoo. A self-hosted Shlink instance on Proxmox provides the
short URLs; scanning `http://<VM-IP>:8080/eq-<id>` opens
`https://os.natura.io/web#id=<id>&cids=6&menu_id=519&action=743&model=maintenance.equipment&view_type=form`.

## Decisions (from brainstorming)

| Question | Decision |
|---|---|
| Deployment state | Greenfield — nothing deployed; repo scaffold (compose, Alpine bootstrap) exists but never run |
| Who scans, from where | Kenny only, on LAN — HTTP-only, no public exposure, no TLS |
| Short domain | VM IP + port (`http://<VM-IP>:8080`) — no DNS setup |
| Odoo integration | **Approach A′**: deterministic slugs (`eq-<id>`) + VM-side sync worker. Odoo server actions cannot make HTTP calls (safe_eval sandbox), and Odoo MCP is read-only, so no automation lives in Odoo. Kenny confirmed he already navigates by `web#id=<id>` manually. |
| Odoo-side changes | UI-only, performed by Kenny following a written guide (template placeholder + ZPL edit). No custom fields, no automations, no module changes. |
| Label | Keep 2.00" × 0.70" stock; **QR-only, centered** (Kenny dropped the Code128 barcode — the QR replaces it) |
| VM static IP | `10.1.0.72` → short URLs are `http://10.1.0.72:8080/eq-<id>` |
| VM provisioning | Claude drives the Proxmox web UI (VE 6.4, node `pve1`) via the Chrome extension. Next free VMID: 113. |

## Architecture

```
Proxmox pve1 → VM 113 "shlink" (Alpine, static LAN IP, 2 vCPU / 2 GB / 15 GB)
  docker compose (this repo, /opt/shlink-natura):
    shlink            :8080   short-URL redirects + REST API   [existing scaffold]
    shlink_db         MariaDB 11                               [existing scaffold]
    shlink_redis      Redis 7                                  [existing scaffold]
    shlink_web_client :8081   admin/stats UI                   [NEW]
    odoo_sync         Python loop, every 15 min                [NEW]

odoo_sync ──XML-RPC (read-only API key)──▶ os.natura.io   (reads equipment IDs)
odoo_sync ──REST (API key)──▶ shlink:8080                 (creates eq-<id> slugs)
Phone ──scan QR──▶ http://<VM-IP>:8080/eq-<id> ──302──▶ os.natura.io equipment form
```

Key property: the short URL is **derivable from the equipment ID alone**, so label
printing never depends on Shlink or the sync being up. The sync only has to make the
slug resolve before someone scans it.

## Components

### 1. Proxmox VM (created via Chrome extension driving the PVE 6.4 UI)

- Upload Alpine Linux "virt" ISO to `local` storage (or reuse if present).
- Create VM 113, name `shlink` (matching `*.ec-local.natura.io` convention is optional
  since access is by IP): 2 vCPU, 2048 MB RAM, 15 GB disk on `local-lvm`, bridge `vmbr0`.
- Install Alpine via the noVNC console (`setup-alpine`), assign a **static IP** (chosen
  during install from the LAN's free range — recorded in `.env` as `DEFAULT_DOMAIN`).
- Run [deploy/setup-alpine.sh](../../../deploy/setup-alpine.sh) (installs Docker, clones
  this repo to `/opt/shlink-natura`), fill `.env`, `make build && make up`.

### 2. Compose additions (this repo)

- `shlink-web-client` service: official `shlinkio/shlink-web-client` image on port 8081.
  Needed locally because app.shlink.io (HTTPS) can't call a plain-HTTP API (mixed content).
- `odoo_sync` service: small Python 3 Alpine image built from `sync/`, restart
  unless-stopped, joined to `shlink_net`.
- `.env.example` gains: `ODOO_URL`, `ODOO_DB`, `ODOO_USER`, `ODOO_API_KEY`,
  `SHLINK_API_KEY`, `LONG_URL_TEMPLATE`, `SYNC_INTERVAL_SECONDS` (default 900),
  `SLUG_PREFIX` (default `eq-`).
- Makefile gains: `make sync` (run one sync immediately), `make logs-sync`.

### 3. Sync worker (`sync/sync.py`, ~100 lines, stdlib only — xmlrpc.client + urllib)

Loop every `SYNC_INTERVAL_SECONDS`:
1. Authenticate to Odoo XML-RPC with a **read-only API key** (Kenny creates it under
   My Profile → Account Security → API Keys).
2. `search_read` on `maintenance.equipment`, domain `[("active","=",true)]`, fields `["id"]`.
3. For each ID, `POST {shlink}/rest/v3/short-urls` with
   `{"longUrl": LONG_URL_TEMPLATE.format(id=id), "customSlug": f"eq-{id}", "findIfExists": false}`.
   A 400 `non-unique-slug` response means the link already exists → skip. All other
   errors are logged; the record is retried next cycle.
4. Log a one-line summary (`checked N, created M, skipped K, errors E`).

First run backfills all existing equipment. Odoo/Shlink downtime → log + retry next
cycle; the container never crashes the stack. Deleted/archived equipment keeps its
short URL (harmless; YAGNI on cleanup).

### 4. Odoo label changes (template ID 284 "IT Asset Tag", model `maintenance.equipment`)

Status at design time:

Layout (Kenny's final call): "NATURA" line, "SN: <serial>" line, QR centered below.

- **DONE via MCP** — placeholder records on `natura.print.placeholder`
  (MCP `create_record` is allowed on this instance):
  - ID 2366: `placeholder = eq_url`, Field = `ID` (ir.model.fields 12712),
    Transform = **Prefix**, Prefix Text = `http://10.1.0.72:8080/eq-`.
  - ID 2367: `placeholder = serial`, Field = `Serial Number` (ir.model.fields 12697),
    no transform.
- **Kenny pastes the ZPL** — MCP `update_record` is blanket-denied on this instance,
  so the `zpl_code` body is replaced manually in the template form. Placeholders are
  referenced as `${name}` (convention observed in existing templates).

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

QR sizing: ~30-char URL (`http://10.1.0.72:8080/eq-182`) → QR version 3 (29 modules)
at ECC M, magnification 3 = 87 dots ≈ 0.43" (module ≈ 0.37 mm — fine for phone
cameras at close range). Vertical budget: text rows end ~y=44, QR spans y=48–135 on
the 142-dot canvas. If the preview shows overflow, drop the SN font to 16 or shift
the QR to y=46.

## Error handling

- Sync: per-record try/except, cycle-level summary logging, `restart: unless-stopped`.
- Shlink down: QR scans fail until it's back; printing unaffected.
- Wrong/rotated Odoo API key: sync logs auth failure every cycle — visible via `make logs-sync`.
- DB backups: existing `make backup` (mysqldump) covers Shlink's link database.

## Acceptance criteria

1. `curl -I http://<VM-IP>:8080/eq-182` → `302` with `Location: https://os.natura.io/web#id=182&...`.
2. Phone on LAN scans the printed 2.00×0.70 tag and lands on the equipment form.
3. Creating a new equipment record in Odoo → its short URL resolves within 15 min
   (or immediately after `make sync`).
4. Labelary preview in the template form renders the new layout without overlap.
5. `docker compose ps` on the VM shows all 5 containers healthy after reboot.

## Out of scope

- HTTPS / public exposure / DNS names (revisit if more users need to scan).
- Odoo module changes, custom fields, automations.
- Cleanup of short URLs for archived equipment.
- Migrating the existing Proxmox host or other VMs.

## Deliverables

1. Repo: compose + `.env.example` + Makefile updates, `sync/` (script, Dockerfile).
2. VM 113 provisioned and stack running (via Chrome extension + guided console steps).
3. `docs/odoo-setup.md` — click-by-click Odoo guide with final ZPL.
4. Deployment runbook updates in the repo docs.
