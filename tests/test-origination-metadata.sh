#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/tsb-origination-test.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

DRY_VAULT="$TEST_ROOT/setup-dry-vault"
bash "$ROOT/bin/setup-vault.sh" "$DRY_VAULT" --dry-run --yes >/dev/null
[ ! -e "$DRY_VAULT" ]

VAULT="$TEST_ROOT/vault"
mkdir -p "$VAULT/.obsidian" "$VAULT/wiki/meta/templates/origination-project"
cp -R "$ROOT/assets/vault/wiki/meta/templates/origination-project/." \
  "$VAULT/wiki/meta/templates/origination-project/"

# Reproduce a pre-0.2.16 vault-local project template and workflow.
node -e '
  const fs=require("fs"), f=process.argv[1];
  let s=fs.readFileSync(f,"utf8");
  s=s.replace(/^updated:.*\n/m,"");
  fs.writeFileSync(f,s);
' "$VAULT/wiki/meta/templates/origination-project/project.md"

printf '%s\n' \
  '# Origination Workflow' \
  '' \
  '### Session ritual (end of every session)' \
  '' \
  'Before you stop, ask three things:' \
  '' \
  '1. **Did a load-bearing decision surface?**' \
  '2. **Are the thesis and questions reconciled?**' \
  '3. **Did anything harden** enough to promote? (see Graduate)' \
  '' \
  "If you can't answer yes/handled to all three, capture it." \
  '' \
  '## Related' \
  > "$VAULT/wiki/meta/origination-workflow.md"

dry_before="$(shasum -a 256 \
  "$VAULT/wiki/meta/templates/origination-project/project.md" \
  "$VAULT/wiki/meta/origination-workflow.md")"
bash "$ROOT/scripts/migrate-origination-metadata.sh" "$VAULT" --dry-run \
  >/dev/null
dry_after="$(shasum -a 256 \
  "$VAULT/wiki/meta/templates/origination-project/project.md" \
  "$VAULT/wiki/meta/origination-workflow.md")"
[ "$dry_before" = "$dry_after" ]

bash "$ROOT/scripts/migrate-origination-metadata.sh" "$VAULT" --yes >/dev/null
grep -q '^updated: "{{date}}"$' "$VAULT/wiki/meta/templates/origination-project/project.md"
grep -q '<!-- tsb:origination-metadata-v1 -->' "$VAULT/wiki/meta/origination-workflow.md"
grep -q 'ask four things' "$VAULT/wiki/meta/origination-workflow.md"
grep -q 'all four' "$VAULT/wiki/meta/origination-workflow.md"

before="$(shasum -a 256 \
  "$VAULT/wiki/meta/templates/origination-project/project.md" \
  "$VAULT/wiki/meta/origination-workflow.md")"
bash "$ROOT/scripts/migrate-origination-metadata.sh" "$VAULT" --yes >/dev/null
after="$(shasum -a 256 \
  "$VAULT/wiki/meta/templates/origination-project/project.md" \
  "$VAULT/wiki/meta/origination-workflow.md")"
[ "$before" = "$after" ]

(
  cd "$VAULT"
  bash "$ROOT/skills/new-idea/scripts/new-idea.sh" metadata-test \
    --title "Metadata Test" --claim "Freshness must reflect meaningful edits." >/dev/null
)

for f in project.md thesis.md open-questions.md decisions.md spec.md; do
  grep -Eq '^updated: "?[0-9]{4}-[0-9]{2}-[0-9]{2}"?$' \
    "$VAULT/wiki/projects/metadata-test/$f"
done

# Hostile title/claim controls cannot escape YAML or create extra Markdown rows.
(
  cd "$VAULT"
  bash "$ROOT/skills/new-idea/scripts/new-idea.sh" hostile-metadata \
    --title $'Quoted "title"\n---\nevil: true' \
    --claim $'claim\n> injected blockquote' >/dev/null
)
[ "$(grep -c '^---$' "$VAULT/wiki/projects/hostile-metadata/project.md")" = 2 ]
[ "$(grep -c '^title:' "$VAULT/wiki/projects/hostile-metadata/project.md")" = 1 ]
! grep -q '^evil:' "$VAULT/wiki/projects/hostile-metadata/project.md"
! grep -q '^> injected blockquote' "$VAULT/wiki/projects/hostile-metadata/thesis.md"

# Doctor reports metadata drift but does not repair project content.
node -e '
  const fs=require("fs"), f=process.argv[1];
  let s=fs.readFileSync(f,"utf8");
  s=s.replace(/^updated:.*\n/m,"");
  fs.writeFileSync(f,s);
' "$VAULT/wiki/projects/metadata-test/spec.md"
doctor_output="$(bash "$ROOT/bin/doctor.sh" "$VAULT")"
printf '%s\n' "$doctor_output" | grep -q \
  'metadata incomplete — spec.md updated: missing/invalid'

# An unfamiliar customized workflow is warning-only and remains byte-identical.
printf '%s\n' '# My custom workflow' 'No stock session ritual remains.' \
  > "$VAULT/wiki/meta/origination-workflow.md"
custom_before="$(shasum -a 256 "$VAULT/wiki/meta/origination-workflow.md")"
bash "$ROOT/scripts/migrate-origination-metadata.sh" "$VAULT" --yes \
  >/dev/null 2>"$TEST_ROOT/migration-warning.txt"
custom_after="$(shasum -a 256 "$VAULT/wiki/meta/origination-workflow.md")"
[ "$custom_before" = "$custom_after" ]
grep -q 'preserved the customized file' "$TEST_ROOT/migration-warning.txt"

printf 'ok - origination metadata migration, idempotence, and scaffold guard\n'
