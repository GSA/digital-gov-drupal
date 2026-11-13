# Drupal 11 upgrade prep: start here

**Audience:** a Claude Code session working in this repo, plus the engineers it works with.
**Written:** 2026-11-13. It's based on the usa.gov (GSA `usagov/usagov-2021`) D10 → D11
preparation, and on a read-only scan of this repo at `develop` @ `42d6ca5e`.

## Goal
Upgrade digital-gov-drupal from Drupal **10.6.20** to **11.4.x** (11.4.11 is the latest at the
time of writing). Do it the way it worked on usa.gov: **finish every change that works on
Drupal 10 first**, each as its own small, verified ticket merged to `develop`. The core bump at
the end should then contain little more than core, its patches and lockfile churn.

## Reading order
1. [`digital-gov-assessment.md`](digital-gov-assessment.md): what this repo needs, how each
   finding was measured, and a proposed ticket sequence. **Re-run the checks before acting;**
   `develop` moves.
2. [`lessons-learned.md`](lessons-learned.md): what went wrong or surprised us on usa.gov, and
   what to do instead. Read this before touching patches, contrib upgrades or Twig.
3. [`verification-recipes.md`](verification-recipes.md): copy-paste commands, adapted to Lando,
   for proving that a change makes no unintended difference to rendered output.

## Ground rules
- **D10 first.** If a change can land on 10.6 (a contrib release that allows `^10 || ^11`, a
  custom-code fix, a patch rebase kept unreferenced), it goes in before the core bump, one ticket
  per item.
- **Keep a living plan doc in the repo.** Copy usa.gov's model: a `docs/` plan listing every
  item, struck through and marked **Done** (ticket, PR) as it lands. Update it in the same
  change that resolves each item.
- **Branch names** follow this repo's convention: `feature/DIGITAL-NNN-short-description`.
  Ask the user for the ticket number; never invent one.
- **Prove "no change" with a byte-level diff against `develop`,** not by eyeballing pages. See
  `verification-recipes.md`. Pick samples that include the edge cases (see "Review lessons" in
  `lessons-learned.md`).
- **Confirm before outward-facing actions:** pushing, opening PRs, PR comments, anything on
  cloud.gov. Report test results faithfully, including failures that aren't yours.
- **PR descriptions** follow `.github/` templates. Include copy-paste validation steps with
  their expected output, and state what you already verified, with real counts.

## First three actions
1. **Re-run the blocker scan and the target check** (`verification-recipes.md` §1). Confirm the
   latest 11.4.x release and that s3fs's band still allows it.
2. **Replace `upgrade_status` 4.3.10 with 5.0.0-alpha3**, enabled only in the `local` config
   split. Run a full scan and record the results in the plan doc. 4.3.10 fatals mid-scan; see
   `lessons-learned.md` §1.
3. **Write `docs/Drupal11UpgradePlan.md`** (or whatever name the team prefers) from the
   assessment and the scan. Get the user to agree the ticket list before starting work.
