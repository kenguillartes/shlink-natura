#!/usr/bin/env python3
"""Odoo -> Shlink sync: ensure every active maintenance.equipment record
has a deterministic short URL (slug "eq-<id>") in Shlink.

Reads equipment IDs from Odoo over XML-RPC (read-only API key) and creates
missing short URLs via Shlink's REST API. Idempotent: existing slugs are
skipped. Runs forever on an interval, or once with --once.

Stdlib only — no pip dependencies.
"""

import json
import logging
import os
import sys
import time
import urllib.error
import urllib.request
import xmlrpc.client

ODOO_URL = os.environ["ODOO_URL"].rstrip("/")
ODOO_DB = os.environ["ODOO_DB"]
ODOO_USER = os.environ["ODOO_USER"]
ODOO_API_KEY = os.environ["ODOO_API_KEY"]

SHLINK_BASE_URL = os.environ.get("SHLINK_BASE_URL", "http://shlink:8080").rstrip("/")
SHLINK_API_KEY = os.environ["SHLINK_API_KEY"]

LONG_URL_TEMPLATE = os.environ["LONG_URL_TEMPLATE"]
SLUG_PREFIX = os.environ.get("SLUG_PREFIX", "eq-")
INTERVAL = int(os.environ.get("SYNC_INTERVAL_SECONDS", "900"))

NON_UNIQUE_SLUG = "https://shlink.io/api/error/non-unique-slug"

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("odoo-sync")


def fetch_equipment_ids():
    common = xmlrpc.client.ServerProxy(f"{ODOO_URL}/xmlrpc/2/common")
    uid = common.authenticate(ODOO_DB, ODOO_USER, ODOO_API_KEY, {})
    if not uid:
        raise RuntimeError("Odoo authentication failed (check ODOO_DB/ODOO_USER/ODOO_API_KEY)")
    models = xmlrpc.client.ServerProxy(f"{ODOO_URL}/xmlrpc/2/object")
    return models.execute_kw(
        ODOO_DB, uid, ODOO_API_KEY,
        "maintenance.equipment", "search",
        [[["active", "=", True]]],
    )


def create_short_url(equipment_id):
    """Returns 'created', 'exists', or 'error'."""
    payload = json.dumps({
        "longUrl": LONG_URL_TEMPLATE.format(id=equipment_id),
        "customSlug": f"{SLUG_PREFIX}{equipment_id}",
        "findIfExists": False,
        "tags": ["odoo-equipment"],
    }).encode()
    req = urllib.request.Request(
        f"{SHLINK_BASE_URL}/rest/v3/short-urls",
        data=payload,
        headers={"Content-Type": "application/json", "X-Api-Key": SHLINK_API_KEY},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30):
            return "created"
    except urllib.error.HTTPError as e:
        try:
            body = json.loads(e.read().decode())
        except Exception:
            body = {}
        if body.get("type") == NON_UNIQUE_SLUG:
            return "exists"
        log.error("equipment %s: HTTP %s %s", equipment_id, e.code, body.get("detail", ""))
        return "error"
    except OSError as e:
        log.error("equipment %s: %s", equipment_id, e)
        return "error"


def run_cycle():
    ids = fetch_equipment_ids()
    counts = {"created": 0, "exists": 0, "error": 0}
    for equipment_id in ids:
        counts[create_short_url(equipment_id)] += 1
    log.info(
        "checked %d equipment records: created %d, already existed %d, errors %d",
        len(ids), counts["created"], counts["exists"], counts["error"],
    )
    return counts["error"] == 0


def main():
    once = "--once" in sys.argv
    while True:
        try:
            ok = run_cycle()
        except Exception:
            log.exception("sync cycle failed")
            ok = False
        if once:
            sys.exit(0 if ok else 1)
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
