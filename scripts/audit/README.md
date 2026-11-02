# Dependency audit scripts

Tools for the recurring dependency-update process: see what's outdated or
vulnerable, apply updates under supervision, and keep track of advisories that
have already been dealt with.

| File | What it is |
| --- | --- |
| `deps-check` | Read-only Markdown report: available updates, security advisories, pinned packages, reviewed advisories. |
| `deps-update` | Interactive updater. Applies the updates you approve, then lists the remaining high/critical advisories as numbered ACTION/TICKET items. |
| `deps-flag` | Records deps-update items as *ticketed* or *ignored* in `reviewed-advisories.json`. |
| `reviewed-advisories.json` | Committed list of advisories already dealt with. |
| `.last-findings.json` | The numbered items from the last `deps-update` run. Local and gitignored; read by `deps-flag`. |
| `lib/reviewed-advisories.sh` | Shared code for the list, sourced by all three scripts. |

All three run on the host, not in Lando, and need `composer` (2.7 or later),
`npm` and `jq` (1.6 or later) on the PATH. Each takes `--help`.

## Workflow

1. **`scripts/audit/deps-check > report.md`** (optional) shows where things
   stand. It changes nothing.
2. **`scripts/audit/deps-update`** (add `--minor` or `--major` for larger
   jumps) applies in-range patch updates on its own, asks about everything
   bigger, applies what you approve, and re-audits. Its final section lists
   what's still vulnerable at high/critical severity:
   - `ACTION #n`: an update within reach fixes it. The item names the command.
   - `TICKET #n`: nothing within reach fixes it. The item has Title/Description
     text ready to paste into Jira.
3. **File tickets** for the items you want to track.
4. **`scripts/audit/deps-flag`** records each item so it stops coming back:

   ```sh
   scripts/audit/deps-flag                    # list the items again
   scripts/audit/deps-flag 1 3 --ticketed DIGITAL-901
   scripts/audit/deps-flag 2 --ignore --ticket DIGITAL-902 --reason "Only used by the theme build"
   scripts/audit/deps-flag -i                 # or go through them one by one
   ```

5. **Commit `reviewed-advisories.json`** with the rest of the update.

On later runs, recorded advisories are left out of the ACTION/TICKET output
and listed under "Reviewed advisories" with their status. Once a fix lands and
an advisory is no longer reported, its entry shows as *no longer reported*.
After that `deps-update` run, `scripts/audit/deps-flag --prune` removes those
entries. For a ticketed entry, that's also a hint the ticket can be closed.

`deps-flag` reads the items from the last `deps-update` run that got as far
as its final section. `--dry-run`, `--preflight-only`, and answering no at
"Proceed with the plan above?" all stop earlier, so they don't save any.
`deps-flag` warns when a lock file has changed since the items were saved.

## Ticketed vs ignored

- **ticketed**: a real vulnerability, tracked in a ticket until the fix lands.
  `deps-update` stops raising it. `deps-check` still counts it as open and
  marks it *ticketed* in the tables.
- **ignored**: a false positive in that context, for example a build-only
  dependency that never handles untrusted input. A reason is required.
  `deps-check` marks it and counts it apart in the summary, as `(+N ignored)`.

Both are recorded per context, meaning per lock file. An advisory ignored for
the theme build is still reported for any other `package-lock.json` it shows
up in.

## `reviewed-advisories.json`

`deps-flag` writes the entries, and editing them by hand is fine too. Every
script checks the file before doing anything and stops on an invalid entry,
because a list that silently failed to load would put every reviewed
advisory back into the output.

```json
[
  {
    "advisory": "GHSA-qr28-fpjm-wq7f",
    "context": "web/themes/custom/digital_gov/package-lock.json",
    "package": "decode-uri-component",
    "status": "ignored",
    "ticket": "DIGITAL-902",
    "reason": "Only reached via gulp-sourcemaps during the theme build.",
    "added": "2026-11-02",
    "review_by": "2027-05-01"
  }
]
```

| Field | Required | Meaning |
| --- | --- | --- |
| `advisory` | yes | Any ID the advisory is published under, case-insensitive. Composer: advisory ID (`SA-CORE-*`, `SA-CONTRIB-*`, `PKSA-*`), CVE, or GHSA. npm: the GHSA ID. |
| `context` | yes | `composer.lock`, or an npm target's `package-lock.json` path from the repo root (`package-lock.json` for the root itself). |
| `status` | yes | `ticketed` or `ignored`. |
| `ticket` | yes | The Jira ticket tracking the fix or recording the review. |
| `reason` | for `ignored` | Why. |
| `package` | no | Only match the advisory on this package. |
| `added` | no | `YYYY-MM-DD`. |
| `review_by` | no | `YYYY-MM-DD`. After this date the entry stops suppressing, and the advisory is reported again (*review overdue*) until someone extends the date or removes the entry. |

## Notes

- **Paths:** path options (`--raw-out`, `--raw-in`, `--classify`, `--findings`)
  are relative to the directory you run the command from. For example,
  `deps-check --raw-out .` run from the repo root saves the raw JSON there.
  The scripts themselves always run from the repo root.
- **Contexts:** the npm targets are `NPM_TARGETS` at the top of `deps-check`
  and `deps-update`. An entry whose context matches no target gets a warning
  and is listed as *unknown context*.
- **Composer's own `audit.ignore`** (in `composer.json`) is a different
  mechanism. `deps-update` only offers it as a last-resort way to unblock a
  resolve, and it hides advisories from these reports entirely. Use this list
  instead.
- **USA.gov:** these scripts are adapted from `bin/audit/` in usagov-2021, and
  fixes move between the two copies.
