#!/usr/bin/env bash

DB="build/cebs.db"
URL="http://example.com?${QUERY_STRING}"
ID=$(urlp --query --query_field=id "${URL}")
ID="${ID:-owl:Thing}"

source .venv/bin/activate
python3 -m gizmos.tree "${DB}" "${ID}"
