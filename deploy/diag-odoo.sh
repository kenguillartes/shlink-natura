#!/bin/sh
# Diagnose Odoo XML-RPC auth using the exact env the sync container sees.
cd "$(dirname "$0")/.."
docker compose -f docker-compose.prod.yml run --rm odoo_sync python -c "
import os, xmlrpc.client
db = os.environ['ODOO_DB']; user = os.environ['ODOO_USER']; key = os.environ['ODOO_API_KEY']
print('db  =', repr(db))
print('user=', repr(user))
print('key length:', len(key), ' first4:', key[:4], ' last4:', key[-4:])
s = xmlrpc.client.ServerProxy(os.environ['ODOO_URL'] + '/xmlrpc/2/common')
print('server:', s.version()['server_version'])
print('auth:', repr(s.authenticate(db, user, key, {})))
"
