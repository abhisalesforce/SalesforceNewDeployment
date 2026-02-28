#!/usr/bin/env bash
# newman-run.sh – Run Postman collection tests via Newman CLI.
#
# Usage:
#   ./newman-run.sh [--collection <file>] [--environment <file>] [--env-var KEY=VALUE ...] [--output-dir <dir>]
#
# Environment variables (can override defaults):
#   NEWMAN_COLLECTION   – path to collection JSON (default: postman-collection-api-tests.json)
#   NEWMAN_ENVIRONMENT  – path to environment JSON (default: postman-environment-setup.json)
#   NEWMAN_OUTPUT_DIR   – directory for reports (default: newman-reports)
#   BASE_URL            – override base_url env var
#   ACCESS_TOKEN        – override access_token env var (masked in output)
#   API_VERSION         – override api_version env var

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
COLLECTION="${NEWMAN_COLLECTION:-postman-collection-api-tests.json}"
ENVIRONMENT="${NEWMAN_ENVIRONMENT:-postman-environment-setup.json}"
OUTPUT_DIR="${NEWMAN_OUTPUT_DIR:-newman-reports}"
EXTRA_ENV_VARS=()

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --collection)  COLLECTION="$2";  shift 2 ;;
    --environment) ENVIRONMENT="$2"; shift 2 ;;
    --env-var)     EXTRA_ENV_VARS+=("$2"); shift 2 ;;
    --output-dir)  OUTPUT_DIR="$2";  shift 2 ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Validate inputs ───────────────────────────────────────────────────────────
if [[ ! -f "$COLLECTION" ]]; then
  echo "❌ Collection file not found: $COLLECTION" >&2
  exit 1
fi

if [[ ! -f "$ENVIRONMENT" ]]; then
  echo "❌ Environment file not found: $ENVIRONMENT" >&2
  exit 1
fi

# ── Check Newman is installed ─────────────────────────────────────────────────
if ! command -v newman &>/dev/null; then
  echo "❌ Newman is not installed. Run: npm install --global newman newman-reporter-htmlextra" >&2
  exit 1
fi

# ── Prepare output directory ──────────────────────────────────────────────────
mkdir -p "$OUTPUT_DIR"
REPORT_FILE="$OUTPUT_DIR/api-test-report.html"
TIMESTAMP=$(date -u +'%Y%m%dT%H%M%SZ')
JUNIT_FILE="$OUTPUT_DIR/api-test-results-${TIMESTAMP}.xml"

echo "▶ Running Newman"
echo "  Collection : $COLLECTION"
echo "  Environment: $ENVIRONMENT"
echo "  Report dir : $OUTPUT_DIR"

# ── Build env-var arguments ───────────────────────────────────────────────────
ENV_VAR_ARGS=()

if [[ -n "${BASE_URL:-}" ]]; then
  ENV_VAR_ARGS+=(--env-var "base_url=${BASE_URL}")
fi

if [[ -n "${ACCESS_TOKEN:-}" ]]; then
  ENV_VAR_ARGS+=(--env-var "access_token=${ACCESS_TOKEN}")
fi

if [[ -n "${API_VERSION:-}" ]]; then
  ENV_VAR_ARGS+=(--env-var "api_version=${API_VERSION}")
fi

for ev in "${EXTRA_ENV_VARS[@]:-}"; do
  ENV_VAR_ARGS+=(--env-var "$ev")
done

# ── Detect available reporters ────────────────────────────────────────────────
REPORTERS="cli"
if npm list -g newman-reporter-htmlextra --depth=0 &>/dev/null 2>&1; then
  REPORTERS="cli,htmlextra"
elif npm list newman-reporter-htmlextra --depth=0 &>/dev/null 2>&1; then
  REPORTERS="cli,htmlextra"
fi

# ── Run Newman ────────────────────────────────────────────────────────────────
NEWMAN_EXIT=0
newman run "$COLLECTION" \
  --environment "$ENVIRONMENT" \
  "${ENV_VAR_ARGS[@]}" \
  --reporters "$REPORTERS" \
  --reporter-htmlextra-export "$REPORT_FILE" \
  --reporter-html-export "$REPORT_FILE" \
  --reporter-junit-export "$JUNIT_FILE" \
  --timeout-request 30000 \
  --color on \
  || NEWMAN_EXIT=$?

# ── Summary ───────────────────────────────────────────────────────────────────
if [[ $NEWMAN_EXIT -eq 0 ]]; then
  echo ""
  echo "✅ All API tests passed."
else
  echo ""
  echo "❌ Some API tests failed (exit code: $NEWMAN_EXIT)."
fi

if [[ -f "$REPORT_FILE" ]]; then
  echo "📄 HTML report: $REPORT_FILE"
fi
if [[ -f "$JUNIT_FILE" ]]; then
  echo "📄 JUnit report: $JUNIT_FILE"
fi

exit $NEWMAN_EXIT
