# shellcheck shell=bash
#
# scripts/audit/lib/false-positives.sh — the known-false-positive list shared
# by scripts/audit/deps-check and scripts/audit/deps-update. Sourced, not run;
# the caller must define info() and die() and set ROOT_DIR first.
#
# scripts/audit/false-positives.json records security advisories that were
# reviewed and found not to apply in one dependency context. It is committed:
# each entry is a reviewed decision, and every run (anyone's) needs it.
#
#   [
#     {
#       "advisory":  "GHSA-qr28-fpjm-wq7f",
#       "context":   "web/themes/custom/digital_gov/package-lock.json",
#       "package":   "decode-uri-component",
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
#              relative to the repo root. An advisory that is a false positive
#              in two contexts needs two entries.
#   ticket     (required) The Jira ticket that records the review.
#   reason     (required) Why the advisory does not apply in this context.
#   package    (optional) Only match the advisory on this package.
#   added      (optional) YYYY-MM-DD, for the reader.
#   review_by  (optional) YYYY-MM-DD. Once it has passed, the entry stops
#              suppressing and the advisory is reported again until someone
#              re-reviews it (extend the date) or removes the entry.
#
# deps-update leaves matched advisories out of its ACTION/TICKET output and
# deps-check marks them in its tables; both list every entry's status, including
# entries whose advisory is no longer reported (safe to remove).

FP_FILE="$ROOT_DIR/scripts/audit/false-positives.json"
FP_TODAY="$(date +%Y-%m-%d)"

# fp_npm_context <npm target dir> — the context string for an npm target.
fp_npm_context() {
  if [ "$1" = "." ]; then echo "package-lock.json"; else echo "$1/package-lock.json"; fi
}

# fp_load <out> <known context>... — validates FP_FILE and writes the list,
# normalized, to <out> (an empty list when the file does not exist). Dies on an
# invalid file: a list that silently fails to load would put every reviewed
# advisory back into the ticket output. Warns about contexts no target uses.
fp_load() {
  local out="$1" known problems; shift
  if [ ! -e "$FP_FILE" ]; then
    echo '[]' >"$out"
    return 0
  fi
  jq -e . "$FP_FILE" >/dev/null 2>&1 || die "$FP_FILE is empty or not valid JSON"
  problems="$(jq -r '
    def entry($i): "entry \($i + 1)\(if (.advisory | type) == "string" then " (\(.advisory))" else "" end)";
    if type != "array" then "the top level must be a JSON array of entries"
    else
      to_entries[] | .key as $i | .value
      | if type != "object" then "entry \($i + 1): not an object"
        else
          ( ["advisory", "context", "ticket", "reason"][] as $k
            | select((.[$k] | type) != "string" or (.[$k] | length) == 0)
            | "\(entry($i)): \"\($k)\" is required (non-empty string)" ),
          ( select(has("package") and ((.package | type) != "string" or .package == ""))
            | "\(entry($i)): \"package\" must be a non-empty string when present" ),
          ( ["added", "review_by"][] as $k
            | select(has($k) and ((.[$k] | type) != "string" or (.[$k] | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}$") | not)))
            | "\(entry($i)): \"\($k)\" must be a YYYY-MM-DD date" )
        end
    end' "$FP_FILE")" || die "could not validate $FP_FILE"
  if [ -n "$problems" ]; then
    printf '%s\n' "$problems" | sed 's/^/  /' >&2
    die "$FP_FILE has invalid entries (see above)"
  fi
  jq 'map(.context |= ltrimstr("./"))' "$FP_FILE" >"$out"
  known="$(printf '%s\n' "$@" | jq -R . | jq -sc .)"
  jq -r --argjson known "$known" '
    .[] | select(.context as $c | any($known[]; . == $c) | not)
    | "\(.advisory): context \"\(.context)\" matches no audit target (known: \($known | join(", ")))"
  ' "$out" | while IFS= read -r line; do
    info "warning: false-positives.json: $line"
  done
}

# jq definitions for matching. Programs that use them must be run with
# --slurpfile fpl <fp_load output> --arg today "$FP_TODAY". (read -d '', not
# $(cat <<EOF): bash 3.2, macOS's /bin/bash, misparses a heredoc inside $(...).)
FP_JQ_DEFS=""
read -r -d '' FP_JQ_DEFS <<'EOF' || true
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
def fp_expired: (.review_by // "") as $r | $r != "" and $r < $today;
# The list entries covering an advisory with these IDs on package $pkg in
# context $ctx, each with its list index as .i. Expired entries included.
def fp_hits($ids; $ctx; $pkg):
  ($ids | map(ascii_upcase)) as $u
  | [ $fpl[0] | to_entries[]
      | .key as $i | .value
      | select(.context == $ctx)
      | select((.advisory | ascii_upcase) as $a | any($u[]; . == $a))
      | select((.package // "") == "" or .package == $pkg)
      | . + {i: $i} ];
# The entry that suppresses the advisory right now, or null.
def fp_active($ids; $ctx; $pkg): fp_hits($ids; $ctx; $pkg) | map(select(fp_expired | not)) | first;
EOF

# fp_status <fp_load output> <known contexts, JSON array> <kind|context|audit json>...
# Prints one Markdown list line per entry with its status this run. kind is
# "composer" or "npm"; pass one spec per context that was audited. A missing
# or failed audit file marks its entries "not checked" rather than stale.
fp_status() {
  local fpj="$1" known="$2" spec kind ctx file hits; shift 2
  hits="$(mktemp)"
  for spec in "$@"; do
    IFS='|' read -r kind ctx file <<<"$spec"
    jq -c --arg kind "$kind" --arg ctx "$ctx" \
          --slurpfile fpl "$fpj" --arg today "$FP_TODAY" "$FP_JQ_DEFS"'
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
                    | .value | advlist[] | fp_hits(composer_ids; $ctx; $p)[] | .i ]
                else
                  [ (.vulnerabilities // {}) | objects | .[] | .name as $p
                    | .via[]? | objects | fp_hits(npm_ids; $ctx; $p)[] | .i ]
                end | unique ) }' "$file" >>"$hits" 2>/dev/null \
      || jq -nc --arg ctx "$ctx" '{ctx: $ctx, ok: false, hits: []}' >>"$hits"
  done
  jq -r -n --slurpfile fpl "$fpj" --slurpfile audited <(jq -s . "$hits") \
        --argjson known "$known" --arg today "$FP_TODAY" "$FP_JQ_DEFS"'
    ($audited[0] | map({key: .ctx, value: .}) | from_entries) as $by
    | $fpl[0] | to_entries[]
    | .key as $i | .value as $e
    | $by[$e.context] as $au
    | ( if any($known[]; . == $e.context) | not then "unknown context — no audit target uses it"
        elif $au == null then "not checked this run"
        elif ($au.ok | not) then "not checked this run (the audit did not complete)"
        elif any($au.hits[]; . == $i) | not then "no longer reported — safe to remove"
        elif ($e | fp_expired) then "REVIEW OVERDUE (review_by \($e.review_by)) — reported again until re-reviewed"
        else "suppressed" end ) as $st
    | "- [\($st)] \($e.advisory)\(if ($e.package // "") != "" then " (\($e.package))" else "" end)"
      + " in `\($e.context)` — \($e.ticket): \($e.reason)"
  '
  rm -f "$hits"
}
