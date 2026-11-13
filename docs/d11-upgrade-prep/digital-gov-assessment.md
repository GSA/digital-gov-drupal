# digital-gov-drupal: D11 readiness assessment

The baseline is the read-only scan of `develop` @ `42d6ca5e` on 2026-11-13. Re-run each check
before relying on it; the commands are in `verification-recipes.md`.

## Platform

| Item | Current | Needed for 11.4 | Status |
| --- | --- | --- | --- |
| Core | 10.6.20 (`core-recommended`, `core-composer-scaffold`, `core-project-message` pinned exactly) | 11.4.x | target |
| PHP (Lando) | 8.3 | ≥ 8.3 | OK |
| MariaDB (Lando) | 10.6 | ≥ 10.6 | OK, at the minimum. Check the cloud.gov RDS version too. |
| Drush | 13.8.0 | 13.x | OK |
| Base theme | `stark` | — | No base-theme major to absorb (on usa.gov, `uswds_base` 2→3 was the biggest unknown). |

## Target version: 11.4.x, not 11.5
`drupal/s3fs` 3.11.0 declares a **banded** core constraint:
`>=8.8 <10.7 || >=11.0 <11.2 || >=11.2.3 <11.4.0 || >=11.4.3 <11.5`. That rules out 11.5 and
11.4.0–11.4.2. Pick the newest 11.4 patch release that has every current security fix (11.4.11
on 2026-11-13). Re-check s3fs's latest release first: a newer s3fs may widen the band.

## Contrib blockers
**Method:** every package in `composer.lock` with a `drupal/core` requirement (74 packages) was
checked with `Composer\Semver\Semver::satisfies('11.4.11', <constraint>)`.

| Package | Locked | Blocks 11.4.11? | Fix | Can land on D10? |
| --- | --- | --- | --- | --- |
| `drupal/log_stdout` | 1.5.0 (`^8.8 \|\| ^9 \|\| ^10`) | **Yes** | 3.0.0 (`^8.8 \|\| ^9 \|\| ^10 \|\| ^11`) | **Yes.** Config **must** add `severity_level: 7`; see `lessons-learned.md` §5. This repo's `config/sync/log_stdout.settings.yml` is identical to usa.gov's, so the trap applies as-is. |
| `drupal/core-recommended` | 10.6.20 | (the bump itself) | 11.4.x | No |

The rest already allow 11.4.11, including the dev or pre-release pins: `maillog dev-1.x`,
`uswds_templates dev-3.0.x` and `openid_connect 3.0.0-alpha8`. `composer prohibits
drupal/core 11.4.11` should agree. It will also list core's Symfony 7.4 requirements; those are
resolved by the bump itself.

Other items for the core-bump ticket:
- `require-dev` has `drupal/core-dev ^10.2`, which must become `^11` (matching the core version).
- `chi-teck/drupal-code-generator` 3.6.1 (via drush) pins `symfony/console ^6.3`. Composer
  should move it during `composer update -W`; check that it does.

## upgrade_status
`drupal/upgrade_status` **4.3.10** is installed and enabled in `config/sync` (so on every
environment). 4.3.10 calls `DeprecationMessage::setFile()`, which doesn't exist, and fatals
partway through a scan ([drupal.org #3607698](https://www.drupal.org/i/3607698), fixed only on
5.x).
- Replace it with `5.0.0-alpha3`, pinned exactly.
- Move its enablement into the `local` config split so it never runs in production.
- Remove it after the upgrade.

## Custom code

| Item | Where | Notes |
| --- | --- | --- |
| `core_version_requirement` excludes `^11` | `ec_uswds`, `ec_shortcodes` (`^9 \|\| ^10`); theme `digital_gov` (`^10`) | Set to `^10 \|\| ^11`. The other 12 custom modules already allow `^11`. |
| Twig `spaceless` (deprecated in Twig 3.12, removed in Twig 4) | `node--short-post--teaser.html.twig:76,80`, `node--news--teaser.html.twig:69` | **Not a D11 blocker**: 11.4 still uses Twig 3 (`^3.28`), so this is optional cleanup. All 3 wrap a `{% set %}` capture of a plain string (a title or an image URL). The same template already uses `\|render\|trim` (line 70), which is the likely replacement. Verify byte-identical output; see `lessons-learned.md` §6. |
| `ConfigFormBase` subclass | `dg_autologout/src/Form/AutologoutSettingsForm.php` | Check that its constructor passes `$typedConfigManager` to the parent. upgrade_status **does not report** this; see `lessons-learned.md` §6. |
| Others | all custom code | Run upgrade_status 5.x, phpstan with deprecation rules, and the checks in `lessons-learned.md` §6. |

## Patches (`composer.patches.json`)
**Method:** each core-level patch was dry-run with `patch --dry-run` against the 11.4.11
sources (`github.com/drupal/core` and `drupal/core-composer-scaffold` tags `11.4.11`).

| Patch | Target | On 11.4.11 | Action |
| --- | --- | --- | --- |
| #2916377 "Allow more characters in CSS identifiers" (drupal.org file `2916377-53.patch`) | `drupal/core` | **1 of 2 hunks FAILS** | Context drift only. 11.4 adds `(string)` casts and re-wraps a comment in `Html::cleanCssIdentifier()`, and the change itself isn't in core. Rebase it as a **new, unreferenced** `_d11` patch file on D10, and swap it in at the bump. `cleanCssIdentifier()` is static, so the usa.gov service-swap technique doesn't apply here. Check whether a newer upstream reroll exists first. |
| `drupal.core-composer-scaffold.implicit-drupal-core-disable.patch` | `drupal/core-composer-scaffold` | Applies cleanly | Re-check at the bump. |
| Contrib patches: `default_content`, `embedded_content`, `maillog`, `migrate_plus`, `openid_connect` (×2), `redis`, `tome` (×3), `sitewide_alert`, `autologout` | contrib | Not tested | These packages don't need a version change for D11, so the patches should keep applying. Re-check during the bump's `composer update`. |

**`composer-exit-on-patch-failure` is not set** in `composer.json`. A patch that no longer
applies only prints a warning, and the build continues **without** it. At the bump, read the
`composer update` output for every "Could not apply patch" line, or dry-run each patch first
(recipe §2).

**Orphaned patch files:** `patches/` contains 3 files that nothing in the repo references
(`git grep` outside `patches/` finds nothing):
- `deafult_content_2698425.patch`
- `default_content-3200212-25.patch`
- `default_content-hook-exclude-content.patch`

They're candidates for deletion in a cleanup ticket.

## Proposed ticket sequence (all on D10 except the last)
1. **upgrade_status 5.0.0-alpha3**, moved to the `local` split, plus a full scan. Turn the
   scan into the plan doc.
2. **`core_version_requirement`** for `ec_uswds`, `ec_shortcodes` and `digital_gov`.
3. **log_stdout 3.0.0**, with `severity_level: 7` (verify all 8 levels; recipe §5).
4. **Custom-code findings** from the scan, the `ConfigFormBase` check, and
   `DependencySerializationTrait` with `private` properties. Split into tickets as needed.
5. **Rebase the #2916377 core patch** as an unreferenced 11.4 file. Dry-run it against 11.4.x
   sources and lint it.
6. Optional: **Twig `spaceless`** and orphaned-patch cleanup.
7. **Core bump:**
   - `core-*` to the target version;
   - `drupal/core-dev ^11`;
   - swap in the rebased patch;
   - `composer update -W`;
   - `drush updb`, then `cim`, then a reviewed `cex`;
   - full verification (rendered pages, the Tome static build, Cypress or other tests);
   - re-run upgrade_status on D11, then remove it.

## Open questions for the team
- Is the cloud.gov database MariaDB/MySQL version at or above D11's minimums?
- Should `upgrade_status` stay enabled in any shared environment during prep, or only locally?
- Which test suites cover this site end to end (Cypress, Behat, other)? Where's the static
  (Tome) build compared before and after?
- Is the #2916377 patch still needed? Does the site still emit CSS identifiers containing
  `. / : @`?
