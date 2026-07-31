#!/usr/bin/env bash

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_PROJECT="$ROOT_DIR/metacasa-ios/project.yml"
ENV_FILE="$ROOT_DIR/.env"
FAILURES=0
WARNINGS=0

pass() { printf 'PASS  %s\n' "$1"; }
warn() { printf 'WARN  %s\n' "$1"; WARNINGS=$((WARNINGS + 1)); }
fail() { printf 'FAIL  %s\n' "$1"; FAILURES=$((FAILURES + 1)); }

http_status() {
  curl --silent --show-error --location --output /dev/null \
    --write-out '%{http_code}' --max-time 15 "$1" 2>/dev/null || printf '000'
}

printf 'Home Finance release preflight\n'
printf '==============================\n'

DOMAIN_STATUS="$(http_status "https://usehomefinance.com")"
if [[ "$DOMAIN_STATUS" == "200" ]]; then
  pass "Developer website is online"
else
  fail "Developer website returned HTTP $DOMAIN_STATUS"
fi

for legal_url in \
  "https://metacasa-app-cf592.web.app/privacy.html" \
  "https://metacasa-app-cf592.web.app/terms.html" \
  "https://metacasa-app-cf592.web.app/account-deletion.html"
do
  status="$(http_status "$legal_url")"
  if [[ "$status" == "200" ]]; then
    pass "Legal page is online: $legal_url"
  else
    fail "Legal page returned HTTP $status: $legal_url"
  fi
done

if [[ -f "$ENV_FILE" ]]; then
  SUPABASE_URL="$(sed -n 's/^VITE_SUPABASE_URL=//p' "$ENV_FILE")"
  SUPABASE_KEY="$(sed -n 's/^VITE_SUPABASE_ANON_KEY=//p' "$ENV_FILE")"
  if [[ -n "$SUPABASE_URL" && -n "$SUPABASE_KEY" ]]; then
    AUTH_STATUS="$(
      curl --silent --show-error --output /dev/null --write-out '%{http_code}' \
        --max-time 15 -H "apikey: $SUPABASE_KEY" "$SUPABASE_URL/auth/v1/health" \
        2>/dev/null || printf '000'
    )"
    if [[ "$AUTH_STATUS" == "200" ]]; then
      pass "Supabase Auth is responding"
    else
      fail "Supabase Auth returned HTTP $AUTH_STATUS"
    fi
  else
    fail "Supabase public configuration is incomplete"
  fi
else
  fail "Root .env file is missing"
fi

MARKETING_VERSION="$(sed -n 's/.*MARKETING_VERSION: *"\([^"]*\)".*/\1/p' "$IOS_PROJECT")"
BUILD_NUMBER="$(sed -n 's/.*CURRENT_PROJECT_VERSION: *"\([^"]*\)".*/\1/p' "$IOS_PROJECT")"
if [[ "$MARKETING_VERSION" == "1.0.3" ]]; then
  warn "iOS is still version 1.0.3; bump before uploading a new release"
else
  pass "iOS marketing version is $MARKETING_VERSION"
fi
printf 'INFO  iOS build number: %s\n' "${BUILD_NUMBER:-unknown}"

AVAILABLE_GB="$(df -g "$ROOT_DIR" | awk 'NR == 2 { print $4 }')"
if [[ "${AVAILABLE_GB:-0}" -lt 15 ]]; then
  warn "Only ${AVAILABLE_GB:-unknown} GB are free; Xcode archives may fail"
else
  pass "$AVAILABLE_GB GB free for builds and archives"
fi

if git -C "$ROOT_DIR" diff --quiet && git -C "$ROOT_DIR" diff --cached --quiet; then
  pass "Git working tree has no uncommitted tracked changes"
else
  warn "Git working tree has changes that must be reviewed before release"
fi

printf '\nSummary: %d failure(s), %d warning(s)\n' "$FAILURES" "$WARNINGS"
if [[ "$FAILURES" -gt 0 ]]; then
  exit 1
fi

