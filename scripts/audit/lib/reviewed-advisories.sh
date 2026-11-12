# shellcheck shell=bash
#
# scripts/audit/lib/reviewed-advisories.sh — the reviewed-advisory list shared
# by scripts/audit/deps-check, deps-update and deps-flag. Sourced, not run; the
# caller must define info() and die() and set ROOT_DIR first. How the pieces
# fit together: scripts/audit/README.md.
#
# scripts/audit/reviewed-advisories.json records security advisories someone
# has already dealt with, one entry per advisory per context. It is committed:
# each entry is a reviewed decision, and every run (anyone's) needs it.
# scripts/audit/deps-flag writes entries; hand edits are fine too.
#
#   [
#     {
#       "advisory":  "GHSA-qr28-fpjm-wq7f",
#       "context":   "web/themes/custom/digital_gov/package-lock.json",
#       "package":   "decode-uri-component",
#       "status":    "ignored",
#       "ticket":    "DIGITAL-123",
#       "reason":    "Only reached via gulp-sourcemaps during the theme build.",
#       "added":     "2026-10-30",
#       "review_by": "2027-04-30"
#     }
#   ]
#
#   advisory   (required) Any ID the advisory is published under, matched
#              case-insensitively. Composer: the advisoryId (SA-CORE-*,
#              SA-CONTRIB-*, PKSA-*), the CVE, or a source ID (GHSA-*) — the
#              same set composer's own audit.ignore matches. npm: the GHSA ID
#              from the advisory URL (npm's numeric source ID also matches).
#   context    (required) The lock file the advisory was reviewed for:
#              composer.lock, or an npm target's package-lock.json path
#              relative to the repo root.
#   status     (required) "ticketed" — a real issue, tracked in `ticket`
#              until the fix lands; or "ignored" — a false positive here.
#   ticket     (required) The Jira ticket that tracks the fix or records the
#              review.
#   reason     (required for "ignored", optional for "ticketed") Why.
#   package    (optional) Only match the advisory on this package.
#   added      (optional) YYYY-MM-DD, for the reader.
#   review_by  (optional) YYYY-MM-DD. Once it has passed, the entry stops
#              suppressing and the advisory is reported again until someone
#              re-reviews it (extend the date) or removes the entry.
#
# deps-update leaves matched advisories out of its ACTION/TICKET output.
# deps-check marks them in its tables; "ignored" ones are also counted apart in
# its summary (a "ticketed" advisory is still a real, open vulnerability).

RA_FILE="$ROOT_DIR/scripts/audit/reviewed-advisories.json"
RA_FINDINGS="$ROOT_DIR/scripts/audit/.last-findings.json"
RA_TODAY="$(date +%Y-%m-%d)"

# ra_npm_context <npm target dir> — the context string for an npm target.
ra_npm_context() {
  if [ "$1" = "." ]; then echo "package-lock.json"; else echo "$1/package-lock.json"; fi
}

# ra_validate <file> — prints one line per problem with a reviewed-advisory
# list (nothing when it is valid).
ra_validate() {
  if ! jq -e . "$1" >/dev/null 2>&1; then
    echo "the file is empty or not valid JSON"
    return 0
  fi
  jq -r '
    def entry($i): "entry \($i + 1)\(if (.advisory | type) == "string" then " (\(.advisory))" else "" end)";
    def str($k): (.[$k] | type) == "string" and (.[$k] | length) > 0;
    if type != "array" then "the top level must be a JSON array of entries"
    else
      to_entries[] | .key as $i | .value
      | if type != "object" then "entry \($i + 1): not an object"
        else
          ( ["advisory", "context", "status", "ticket"][] as $k
            | select(str($k) | not)
            | "\(entry($i)): \"\($k)\" is required (non-empty string)" ),
          ( select(str("status") and .status != "ticketed" and .status != "ignored")
            | "\(entry($i)): \"status\" must be \"ticketed\" or \"ignored\"" ),
          ( select(.status == "ignored" and (str("reason") | not))
            | "\(entry($i)): \"reason\" is required for an ignored advisory" ),
          ( ["package", "reason"][] as $k
            | select(has($k) and (str($k) | not))
            | "\(entry($i)): \"\($k)\" must be a non-empty string when present" ),
          ( ["added", "review_by"][] as $k
            | select(has($k) and ((.[$k] | type) != "string" or (.[$k] | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$") | not)))
            | "\(entry($i)): \"\($k)\" must be a YYYY-MM-DD date" )
        end
    end' "$1"
}

# ra_load <out> <known context>... — validates RA_FILE and writes the list,
# normalized, to <out> (an empty list when the file does not exist). Dies on an
# invalid file: a list that silently fails to load would put every reviewed
# advisory back into the ticket output. Warns about contexts no target uses.
ra_load() {
  local out="$1" known problems; shift
  if [ ! -e "$RA_FILE" ]; then
    echo '[]' >"$out"
    return 0
  fi
  problems="$(ra_validate "$RA_FILE")" || die "could not validate $RA_FILE"
  if [ -n "$problems" ]; then
    printf '%s\n' "$problems" | sed 's/^/  /' >&2
    die "$RA_FILE is invalid (see above)"
  fi
  jq 'map(.context |= ltrimstr("./"))' "$RA_FILE" >"$out"
  known="$(printf '%s\n' "$@" | jq -R . | jq -sc .)"
  jq -r --argjson known "$known" '
    .[] | select(.context as $c | any($known[]; . == $c) | not)
    | "\(.advisory): context \"\(.context)\" matches no audit target (known: \($known | join(", ")))"
  ' "$out" | while IFS= read -r line; do
    info "warning: reviewed-advisories.json: $line"
  done
}

# jq definitions for matching. Programs that use them must be run with
# --slurpfile reviewed <ra_load output> --arg today "$RA_TODAY". (read -d '',
# not $(cat <<EOF): bash 3.2, macOS's /bin/bash, misparses a heredoc inside
# $(...).)
RA_JQ_DEFS=""
read -r -d '' RA_JQ_DEFS <<'EOF' || true
# Every ID a composer advisory is published under.
def composer_ids: [.advisoryId, .cve, (.sources // [] | .[]? | .remoteId?)]
  | map(select(type == "string" and . != ""));
# Every ID an npm advisory (an object in a vulnerability's .via) carries: the
# GHSA from its URL, and npm's numeric source ID.
def npm_ids: [((.url // "") | tostring | match("GHSA-[0-9A-Za-z-]+"; "g").string),
              (.source // empty | tostring)]
  | map(select(. != ""));
# The ID to show for an npm advisory: its GHSA when it has one.
def npm_id: (npm_ids | map(select(startswith("GHSA-"))) | first) // ((.source // "?") | tostring);
def sevrank: (ascii_downcase) as $s
  | {"critical": 4, "high": 3, "moderate": 2, "low": 1, "info": 0} | .[$s] // -1;
# Sort key that puts the worst npm severity first.
def worstfirst: 4 - sevrank;
def ra_expired: (.review_by // "") as $r | $r != "" and $r < $today;
# The list entries covering an advisory with these IDs on package $pkg in
# context $ctx, each with its list index as .i. Expired entries included.
def ra_hits($ids; $ctx; $pkg):
  ($ids | map(ascii_upcase)) as $u
  | [ $reviewed[0] | to_entries[]
      | .key as $i | .value
      | select(.context == $ctx)
      | select((.advisory | ascii_upcase) as $a | any($u[]; . == $a))
      | select((.package // "") == "" or .package == $pkg)
      | . + {i: $i} ];
# The entry that suppresses the advisory right now, or null.
def ra_active($ids; $ctx; $pkg): ra_hits($ids; $ctx; $pkg) | map(select(ra_expired | not)) | first;
EOF

# ra_states <ra_load output> <known contexts, JSON array> <kind|context|audit json>...
# Prints a JSON array: each list entry plus .state, one of suppressed,
# overdue, not-reported, unknown-context, not-checked, audit-failed. kind is
# "composer" or "npm"; pass one spec per context that was audited. A missing
# or failed audit file marks its entries audit-failed rather than stale.
ra_states() {
  local rj="$1" known="$2" spec kind ctx file hits; shift 2
  hits="$(mktemp)"
  for spec in "$@"; do
    IFS='|' read -r kind ctx file <<<"$spec"
    jq -c --arg kind "$kind" --arg ctx "$ctx" \
          --slurpfile reviewed "$rj" --arg today "$RA_TODAY" "$RA_JQ_DEFS"'
      def advlist:
        if type == "array" then .
        elif type == "object" then
          (if (has("advisoryId") or has("packageName") or has("title"))
           then [.] else [.[]?] end)
        else [] end;
      { ctx: $ctx,
        ok: (if $kind == "composer" then has("advisories") else has("vulnerabilities") end
             and (has("__error__") | not)),
        hits: ( if $kind == "composer" then
                  [ (.advisories // {}) | objects | to_entries[] | .key as $p
                    | .value | advlist[] | ra_hits(composer_ids; $ctx; $p)[] | .i ]
                else
                  [ (.vulnerabilities // {}) | objects | .[] | .name as $p
                    | .via[]? | objects | ra_hits(npm_ids; $ctx; $p)[] | .i ]
                end | unique ) }' "$file" >>"$hits" 2>/dev/null \
      || jq -nc --arg ctx "$ctx" '{ctx: $ctx, ok: false, hits: []}' >>"$hits"
  done
  jq -c -n --slurpfile reviewed "$rj" --slurpfile audited <(jq -s . "$hits") \
        --argjson known "$known" --arg today "$RA_TODAY" "$RA_JQ_DEFS"'
    ($audited[0] | map({key: .ctx, value: .}) | from_entries) as $by
    | [ $reviewed[0] | to_entries[]
        | .key as $i | .value as $e
        | $by[$e.context] as $au
        | $e + { state: (
            if any($known[]; . == $e.context) | not then "unknown-context"
            elif $au == null then "not-checked"
            elif ($au.ok | not) then "audit-failed"
            elif any($au.hits[]; . == $i) | not then "not-reported"
            elif ($e | ra_expired) then "overdue"
            else "suppressed" end ) } ]
  '
  rm -f "$hits"
}

# ra_render — reads ra_states output on stdin and prints one Markdown list
# line per entry.
ra_render() {
  jq -r '.[]
    | ( if .state == "suppressed" then "suppressed"
        elif .state == "overdue" then "REVIEW OVERDUE (review_by \(.review_by)) — reported again until re-reviewed"
        elif .state == "not-reported" then "no longer reported — safe to remove"
          + (if .status == "ticketed" then "; the fix may have landed, check the ticket" else "" end)
        elif .state == "unknown-context" then "unknown context — no audit target uses it"
        elif .state == "audit-failed" then "not checked this run (the audit did not complete)"
        else "not checked this run" end ) as $st
    | "- [\($st)] \(.advisory)\(if (.package // "") != "" then " (\(.package))" else "" end)"
      + " in `\(.context)` — \(.status), \(.ticket)\(if (.reason // "") != "" then ": \(.reason)" else "" end)"'
}
