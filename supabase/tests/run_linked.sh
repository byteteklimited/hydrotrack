#!/usr/bin/env bash
# Runs the pgTAP suites in supabase/tests/database against the LINKED
# Supabase project without Docker, via the CLI's Management API query.
# Each suite runs in one transaction and rolls itself back, so nothing it
# creates persists. Exits non-zero on any failing assertion or SQL error.
#
# With Docker available, `supabase test db --linked` runs the same files.
set -euo pipefail
cd "$(dirname "$0")/../.."

# Guard: never run against the original sash_water production project.
SASH_PROJECT_REF="freamtqnexxlbyfxowcl"
linked_ref="$(cat supabase/.temp/project-ref 2>/dev/null || true)"
if [[ -z "$linked_ref" ]]; then
  echo "No linked project. Run: supabase link --project-ref <hydrotrack-ref>" >&2
  exit 1
fi
if [[ "$linked_ref" == "$SASH_PROJECT_REF" ]]; then
  echo "Refusing to run: this folder is linked to the sash_water project." >&2
  exit 1
fi
echo "Running database tests against project $linked_ref"

status=0
for suite in supabase/tests/database/*.test.sql; do
  echo "== $suite"
  output="$(supabase db query --linked -f "$suite" 2>/dev/null || true)"
  if ! printf '%s' "$output" | python3 -c '
import json, sys
raw = sys.stdin.read()
start = raw.find("{")
try:
    data = json.loads(raw[start:])
except ValueError:
    print(raw or "No output (query failed to run)"); sys.exit(1)
if "rows" not in data:
    print(json.dumps(data, indent=2)); sys.exit(1)
lines = [next(iter(r.values())) for r in data["rows"]]
print("\n".join(lines))
failed = [l for l in lines if l.lstrip().startswith("not ok")]
passed = sum(1 for l in lines if l.startswith("    ok "))
print(f"-- {passed} assertions passed, {len(failed)} failing lines")
sys.exit(1 if failed or not lines else 0)
'; then
    status=1
  fi
done
exit $status
