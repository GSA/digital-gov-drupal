# Drupal 11 upgrade plan

Living plan for upgrading digital-gov-drupal from Drupal **10.6.20** to **11.4.x**. Each item
lands on Drupal 10 as its own ticket and PR, except the final core bump. When an item merges,
strike it through and mark it **Done** (ticket, PR) in the same change.

Background, method and pitfalls: [`d11-upgrade-prep/`](d11-upgrade-prep/README.md).

## Target
- **Drupal 11.4.12**, the newest 11.4 release as of 2026-11-17. Re-check for a newer 11.4
  security release right before the bump.
- 11.5 is ruled out: `drupal/s3fs` 3.12.0 (latest) allows only
  `>=11.4.3 <11.5` within 11.x.

## Status (2026-11-17, branch `feature/DIGITAL-911-d11-upgrade-prep`)

### Contrib blockers
Semver check of every locked package with a `drupal/core` requirement (75 packages) against
11.4.12, confirmed by `composer prohibits drupal/core 11.4.12`:

| Package | Locked | Fix | Lands on D10? |
| --- | --- | --- | --- |
| `drupal/log_stdout` | 1.5.0 (`^8.8 \|\| ^9 \|\| ^10`) | 3.0.0 (`^8.8 \|\| ^9 \|\| ^10 \|\| ^11`) | Yes |
| `drupal/core-recommended` | 10.6.20 | 11.4.x | No (the bump) |

Every other package already allows 11.4.12.

### upgrade_status 5.0.0 scan
Command: `lando drush us-a --all --format=csv`. It covered 84 projects, and 79 were "Nothing to do".

| Project | Category | Finding |
| --- | --- | --- |
| `log_stdout` | Update | 3.0.0 is D11-ready (item 3) |
| `ec_shortcodes`, `ec_uswds` | Update requirements | `core_version_requirement: ^9 \|\| ^10` (item 2) |
| `digital_gov` theme | Update requirements | `core_version_requirement: ^10` (item 2) |
| `digital_gov` theme | After Drupal 11 | Twig `spaceless` ×5: `node--short-post--teaser` :76, :80; `node--news--teaser` :69; `paragraph--internal-content--featured-links` :45, :52 (item 6) |
| `ec_uswds` | After Drupal 11 | `ec_uswds.module:37`: `template_preprocess_ec_usasummarybox()` needs `'initial preprocess'` (deprecated 11.3, removed 12.0) (item 7) |
| `dg_autologout` | After Drupal 11 | `js/autologout.js:164`: `dialogClass` dialog option (deprecated 10.3, ignored in 12.0) (item 7) |
| `digital_gov_migration` | Remove | Custom module that isn't installed (open question) |

The only other "Update requirements" hit is a test module inside `config_split`, which is never installed.

### Manual checks (upgrade_status doesn't report these)
| Check | Result |
| --- | --- |
| `ConfigFormBase` passes `$typedConfigManager` | OK. `AutologoutSettingsForm` passes `config.typed` to the parent. |
| `private` properties on serializable classes | **1:** `AutologoutSettingsForm::$maxAllowedTimeout` (line 34) (item 4) |
| `attach_library()` without an extension prefix | None |
| `core_version_requirement` without `^11` | `ec_shortcodes`, `ec_uswds`, `digital_gov` (item 2) |

### Patches
| Patch | On 11.4 | Action |
| --- | --- | --- |
| `drupal/core` #2916377 (`2916377-53.patch`) | 1 of 2 hunks fails (context drift) | Rebase as an unreferenced `_d11` file (item 5) |
| `core-composer-scaffold` implicit-drupal-core-disable | Applies | Re-check at the bump |
| Contrib patches | Not tested | Packages don't change for D11; re-check during the bump |

`composer-exit-on-patch-failure` is not set, so at the bump, read the `composer update` output for every "Could not apply patch" line.

Orphaned patch files (nothing references them): `deafult_content_2698425.patch`,
`default_content-3200212-25.patch`, `default_content-hook-exclude-content.patch` (item 6).

## Items

1. ~~**upgrade_status 5.0.0 in `require-dev`, enabled only in the `local` split; full scan; this plan.**~~
   **Done** (DIGITAL-911, PR TBD). 4.3.10 fataled mid-scan. 5.0.0 stable has been released
   since the prep docs were written, so it's pinned instead of 5.0.0-alpha3. Its post-update
   deletes `upgrade_status.settings`, so that file is removed from `config/sync`.
2. ~~**`core_version_requirement: ^10 || ^11`** for `ec_shortcodes`, `ec_uswds` and the
   `digital_gov` theme.~~ **Done** (DIGITAL-914, PR TBD). A rescan shows no "Update
   requirements" for these three projects.
3. ~~**log_stdout 3.0.0** with `severity_level: 7` in `config/sync/log_stdout.settings.yml`.
   Verify all 8 levels (recipes §5).~~ **Done** (DIGITAL-915, PR TBD). All 8 levels log
   (5 to stderr, 3 to stdout), identical to 1.5.0 apart from the date. Negative control:
   without `severity_level`, only EMERGENCY logs.
4. ~~**`AutologoutSettingsForm::$maxAllowedTimeout`**: change it from `private` to `protected`,
   then run a serialize round-trip.~~ **Done** (DIGITAL-916, PR TBD). As `private`, the
   property was left out of the serialized form and came back only through the class
   default. As `protected`, it's serialized, and the injected services are still restored.
   `max_timeout` validation still rejects values above 2147483.
5. **Rebase the #2916377 core patch** against 11.4.12 as an unreferenced `_d11` file. Check
   for a newer upstream reroll first. (DIGITAL-917)
6. *Optional:* replace Twig `spaceless` (5 uses), with byte-identical output verified, and
   delete the 3 orphaned patch files. (DIGITAL-918)
7. *Optional (D12 prep):* add `'initial preprocess'` to `ec_usasummarybox` and replace the
   `dialogClass` option in `dg_autologout`. (DIGITAL-919)
8. **Core bump to 11.4.x** (DIGITAL-920):
   - set `core-recommended`, `core-composer-scaffold` and `core-project-message` to the target;
   - change `drupal/core-dev` to `^11`;
   - **remove the `consolidation/robo: ~5.1.0` pin** in `require-dev`. It was added because
     Robo 5.2 needs Symfony Console 7.4, which arrives with this bump;
   - swap in the rebased #2916377 patch;
   - run `composer update -W` and check that `chi-teck/drupal-code-generator` moves off
     `symfony/console ^6.3`;
   - run `drush updb`, then `cim`, then a reviewed `cex`;
   - do full verification: rendered pages, the Tome static build, and tests;
   - re-run upgrade_status on D11, then remove it.

## Open questions
- Is the cloud.gov database (MariaDB/MySQL) at or above D11's minimum version?
- Can the uninstalled custom module `digital_gov_migration` be deleted?
- Which test suites cover the site end to end? Where should the Tome static build be compared
  before and after?
- Is the #2916377 patch still needed? Does the site still emit CSS identifiers containing
  `. / : @`?
