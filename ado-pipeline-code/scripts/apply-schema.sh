#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# AstraDB Schema Apply Script (DDL only)
# - Applies versioned schema scripts from ./schema (V###__desc.cql)
# - Tracks applied versions in schema_versions table
# - Skips already applied versions
# - Fails if an applied version's checksum changes
# ------------------------------------------------------------------------------

: "${ASTRA_DB_ID:?Missing ASTRA_DB_ID}"
: "${ASTRA_REGION:?Missing ASTRA_REGION}"
: "${ASTRA_TOKEN:?Missing ASTRA_TOKEN}"
: "${ASTRA_KEYSPACE:?Missing ASTRA_KEYSPACE}"

BASE_URL="https://${ASTRA_DB_ID}-${ASTRA_REGION}.apps.astra.datastax.com"
CQL_URL="${BASE_URL}/api/rest/v2/cql?keyspace=${ASTRA_KEYSPACE}"

echo "=========================================="
echo "AstraDB Schema Apply (DDL only)"
echo "Base URL : ${BASE_URL}"
echo "Keyspace : ${ASTRA_KEYSPACE}"
echo "=========================================="

cql_exec () {
  local cql="$1"
  curl --fail-with-body -sS -X POST "${CQL_URL}" \
    -H "X-Cassandra-Token: ${ASTRA_TOKEN}" \
    -H "Content-Type: text/plain" \
    --data "${cql}"
}

cql_run () {
  local cql="$1"
  cql_exec "${cql}" >/dev/null
}

cql_query_json () {
  local cql="$1"
  cql_exec "${cql}"
}

echo "Ensuring schema_versions table exists..."
cql_run "CREATE TABLE IF NOT EXISTS schema_versions (
  version text PRIMARY KEY,
  description text,
  script text,
  checksum text,
  applied_by text,
  applied_on timestamp,
  execution_time_ms int,
  success boolean
);"

if [ ! -d "schema" ]; then
  echo "No ./schema directory found. Nothing to apply."
  exit 0
fi

mapfile -t files < <(find schema -type f -name 'V*__*.cql' | sort)

if [ ${#files[@]} -eq 0 ]; then
  echo "No schema scripts found (expected schema/V###__description.cql)."
  exit 0
fi

# Azure DevOps provides BUILD_REQUESTEDFOR; fallback to who is available.
applied_by="${BUILD_REQUESTEDFOR:-${BUILD_QUEUEDBY:-pipeline}}"

for file in "${files[@]}"; do
  base="$(basename "$file")"
  version="${base%%__*}"
  desc="${base#*__}"
  desc="${desc%.cql}"

  checksum="$(sha256sum "$file" | awk '{print $1}')"

  echo "------------------------------------------"
  echo "Schema version : ${version}"
  echo "Description    : ${desc}"
  echo "File           : ${file}"
  echo "Checksum       : ${checksum}"

  existing="$(cql_query_json "SELECT version, checksum FROM schema_versions WHERE version='${version}';")"

  if echo "$existing" | grep -q "\"version\""; then
    if ! echo "$existing" | grep -q "$checksum"; then
      echo "ERROR: Schema version ${version} was already applied but the file has changed."
      echo "Do NOT modify applied schema files. Create a new version instead."
      exit 2
    fi
    echo "Already applied. Skipping."
    continue
  fi

  cql="$(cat "$file")"

  if ! echo "$cql" | tr -d ' \t\r\n' | grep -q '.'; then
    echo "ERROR: Schema file is empty: ${file}"
    exit 3
  fi

  semicolons="$(echo "$cql" | grep -o ';' | wc -l | tr -d ' ')"
  if [ "${semicolons}" -gt 1 ]; then
    echo "ERROR: Multiple statements detected in ${file}."
    echo "This runner expects ONE DDL statement per file."
    echo "Split into multiple schema/V###__*.cql files."
    exit 4
  fi

  echo "Applying schema change..."
  start_ms=$(date +%s%3N)

  cql_run "$cql"

  end_ms=$(date +%s%3N)
  elapsed=$((end_ms - start_ms))

  cql_run "INSERT INTO schema_versions (
      version, description, script, checksum, applied_by, applied_on, execution_time_ms, success
    ) VALUES (
      '${version}', '${desc}', '${file}', '${checksum}', '${applied_by}', toTimestamp(now()), ${elapsed}, true
    );"

  echo "Applied ${version} in ${elapsed} ms"
done

echo "------------------------------------------"
echo "Schema application completed successfully."
echo "=========================================="
