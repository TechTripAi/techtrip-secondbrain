#!/usr/bin/env bash
# Bring techtrip-secondbrain-owned origination workflow/template artifacts up to
# the metadata-v1 contract without replacing unrelated vault customizations.
# Existing project content is deliberately report-only in doctor.sh: stamping
# an untouched page with today's date would make its freshness metadata lie.
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPTS_DIR/common.sh"
parse_common_flags "$@"; set -- ${TSB_ARGS[@]+"${TSB_ARGS[@]}"}

VAULT="$(default_vault_path "${1:-}")"
WORKFLOW="$VAULT/wiki/meta/origination-workflow.md"
PROJECT_TEMPLATE="$VAULT/wiki/meta/templates/origination-project/project.md"

if [ -f "$PROJECT_TEMPLATE" ]; then
  if ! run "Ensure origination project template has updated: metadata" -- \
    node -e '
      const fs=require("fs"), f=process.argv[1];
      let s=fs.readFileSync(f,"utf8");
      const close=s.indexOf("\n---",4);
      if(!s.startsWith("---\n")||close<0) throw new Error("missing YAML frontmatter: "+f);
      const fm=s.slice(4,close);
      // Preserve any non-empty custom date expression. The new-idea stamping
      // guard resolves the generated page to a concrete YYYY-MM-DD.
      if(/^updated:\s*\S.*$/m.test(fm)) process.exit(0);
      if(/^updated:\s*.*$/m.test(fm)) {
        s=s.replace(/^updated:\s*.*$/m,"updated: \"{{date}}\"");
      } else {
        if(!/^created:\s*.*$/m.test(fm)) throw new Error("frontmatter has no created: insertion anchor: "+f);
        s=s.replace(/^(created:\s*.*)$/m,"$1\nupdated: \"{{date}}\"");
      }
      fs.writeFileSync(f,s);
    ' "$PROJECT_TEMPLATE"; then
    warn "Could not locate safe frontmatter anchors in $PROJECT_TEMPLATE; preserved the customized file."
    warn "Manually add updated: \"{{date}}\" to its YAML frontmatter."
  fi
fi

if [ -f "$WORKFLOW" ]; then
  if ! run "Ensure origination session ritual checks updated: metadata" -- \
    node -e '
      const fs=require("fs"), f=process.argv[1];
      let s=fs.readFileSync(f,"utf8");
      const marker="<!-- tsb:origination-metadata-v1 -->";
      if(s.includes(marker)) process.exit(0);
      const start=s.indexOf("### Session ritual (end of every session)");
      const end=start<0?-1:s.indexOf("\n## ",start);
      const anchor="\nIf you can\x27t answer yes/handled";
      const at=start<0||end<0?-1:s.indexOf(anchor,start);
      if(start<0||end<0||at<0||at>end) process.exit(2);
      const check="\n4. **Is the metadata honest?** Review every project or substrate content page\n   changed this session. Does each have `updated:` set to today\x27s `YYYY-MM-DD`?\n   Add the field if it is missing. (`index.md`, `log.md`, and `hot.md` are\n   operational pages and are exempt.) "+marker+"\n";
      s=s.slice(0,at)+check+s.slice(at);
      s=s.replace("Before you stop, ask three things:","Before you stop, ask four things:");
      s=s.replace("answer yes/handled to all three","answer yes/handled to all four");
      fs.writeFileSync(f,s);
    ' "$WORKFLOW"; then
    warn "Could not locate the stock Session ritual in $WORKFLOW; preserved the customized file."
    warn "Manually add the metadata check from the bundled origination-workflow.md."
  fi
fi
