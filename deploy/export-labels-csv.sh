#!/bin/sh
# Export active equipment as CSV (id, name, serial, url) for label-merge
# printing (e.g. Brother P-touch Editor). Uses the sync container's Odoo creds.
# Usage: sh deploy/export-labels-csv.sh > equipment-labels.csv
cd "$(dirname "$0")/.."
docker compose -f docker-compose.prod.yml run --rm --quiet-pull odoo_sync python -c "
import csv, io, os, sys, xmlrpc.client
url = os.environ['ODOO_URL']; db = os.environ['ODOO_DB']
user = os.environ['ODOO_USER']; key = os.environ['ODOO_API_KEY']
base = 'http://' + os.environ.get('SHORT_DOMAIN', '10.1.0.72:8080')
uid = xmlrpc.client.ServerProxy(url + '/xmlrpc/2/common').authenticate(db, user, key, {})
rows = xmlrpc.client.ServerProxy(url + '/xmlrpc/2/object').execute_kw(
    db, uid, key, 'maintenance.equipment', 'search_read',
    [[('active', '=', True)]], {'fields': ['id', 'name', 'serial_no'], 'order': 'id'})
out = io.StringIO()
w = csv.writer(out)
w.writerow(['id', 'name', 'serial', 'url'])
for r in rows:
    w.writerow([r['id'], r['name'], r['serial_no'] or '', base + '/eq-%d' % r['id']])
sys.stdout.write(out.getvalue())
" 2>/dev/null
