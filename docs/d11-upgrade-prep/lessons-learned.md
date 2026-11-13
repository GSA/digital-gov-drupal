# Lessons from the usa.gov D10 → D11 preparation

Each entry gives **what happened**, **why**, and **what to do**. Most entries apply to any
Drupal 10.6 → 11.4 upgrade; entries marked **(this repo)** also apply directly to
digital-gov-drupal.

## 1. Assessment
- **upgrade_status 4.3.10 fatals partway through a scan (this repo).** It calls
  `DeprecationMessage::setFile()`, which doesn't exist, and dies on any extension whose Twig
  templates attach a deprecated library ([#3607698](https://www.drupal.org/i/3607698)). The fix
  shipped only on 5.x. **Do:** pin `drupal/upgrade_status: 5.0.0-alpha3` in `require-dev`, enable
  it only in the local config split, and remove it once the upgrade is done. Don't patch 4.3.10;
  usa.gov tried that, and review pushed it to 5.x.
- **upgrade_status misses some breakers.** It reported zero "fix now" items in usa.gov's custom
  code. Even so, two real D11 problems turned up that it didn't flag (§6). **Do:** treat its
  report as a starting list, and also run phpstan with `phpstan-deprecation-rules` plus the §6
  checks.
- **`composer prohibits drupal/core <target>` is the live blocker list.** Re-run it after each
  ticket merges. Its first-level lines are the contrib blockers; the Symfony 7.4 lines underneath
  core are resolved by the bump itself.

## 2. Choosing the target version
- **Look for banded constraints (this repo).** s3fs 3.11 allows only
  `>=11.4.3 <11.5` within 11.x and skips 11.2.0–11.2.2 and 11.4.0–11.4.2. On usa.gov this ruled
  out 11.5 and fixed the minor version.
- **Pin an exact patch release** (`core-recommended`, `core-composer-scaffold` and
  `core-project-message` all at, say, `11.4.11`), as this repo already does for 10.6.20. Choose
  the newest patch release that has every security advisory. Re-check right before the bump,
  because usa.gov's target moved from 11.4.7 to 11.4.11 during prep.

## 3. Sequencing: land everything you can on D10 first
- **Contrib releases that allow `^10 || ^11` can be upgraded now, one ticket each.** This kept
  the eventual core bump small. Each upgrade was verified on its own against `develop`.
- **Some modules can only move with core.** For example, usa.gov's `node_menus` dev-3.x needs
  `^11.2`. List those as part of the core-bump ticket.
- **Rebase core patches early, but keep them unreferenced.** Write the new patch file (for
  example `foo_d11.patch`) on D10, but leave `composer.json` / `composer.patches.json` pointing
  at the D10 version until the core bump swaps them. A patch that targets 11.4 won't apply to
  10.6.
- **Use a "workahead" branch while PRs wait for review.** Create
  `feature/DIGITAL-NNN-d11-workahead` from the prep branch. Merge each PR branch that's awaiting
  review into it (always `git merge`, never cherry-pick, so commit SHAs match), push it, and
  never open it as a PR. Start new tickets from it. When review changes land on a PR branch,
  merge that branch in again. This works because `develop` merges PRs with real merge
  commits; that was confirmed on 2026-11-13, when `git log --first-parent develop` showed
  2-parent merges. So the shared commits drop out of diffs once the PRs merge.
- **A long-lived summary PR helps the team.** usa.gov kept one integration PR open, never meant
  to merge, so staff could see the whole change set in one place.

## 4. Patch strategy
- **Classify every patch:** does it apply to the target? Is it still needed? Does it target a
  package whose version changes? Dry-run each against the target sources (recipe §2).
- **Delete orphaned patch files** that no patch list references (this repo has 3; see the
  assessment).
- **Prefer custom code to a core patch when core lets you swap a service.** usa.gov replaced a
  5-file core patch (menu active-trail ordering) with code in a custom module that runs
  unchanged on 10.6 and 11.4:
  - **Use a `ServiceModifierInterface` service provider that only calls `setClass()`.** It keeps
    the original constructor arguments, so it doesn't matter that core's constructor signatures
    differ between 10.6 and 11.x. Inject anything extra through setters, using
    `addMethodCall()`.
  - **Lazy services need a generated proxy class.** For example, `menu.active_trail` is
    `lazy: true` on both 10.6 and 11.4. Swapping its class without a proxy logs "Missing proxy
    class … for lazy service" on every container build. Generate one with
    `php core/scripts/generate-proxy-class.php '<Class>' modules/custom/<module>/src`, commit it,
    and exclude `*/src/ProxyClass/*` from phpstan.
  - **Look for contrib that bypasses the container.** menu_breadcrumb's "derived active trail"
    mode does `new MenuActiveTrail(...)` with core's class, so the swap didn't apply there. The
    fix was to swap `menu_breadcrumb.breadcrumb.default` too, with a subclass whose `applies()`
    is copied from upstream with one change. Its docblock names the source version, so it can
    be re-diffed when the module updates. That parent kept state in **private** properties, so
    the subclass writes them through the public setters. The one setter with a non-nullable
    type is written through `\Closure::bind(fn…, $this, Parent::class)`.
  - **Keep D10 behaviour where D11 core changed it.** D11's `getActiveLink()` skips disabled
    links. Pages that are deliberately kept out of the menu with a disabled link lost their
    breadcrumb and sidebar until a fallback restored the old behaviour.
  - **This doesn't help with static methods.** This repo's #2916377 patch changes
    `Html::cleanCssIdentifier()`, so it needs a rebase instead.

## 5. Contrib upgrade traps
- **log_stdout 1.x → 3.0 silently stops logging (this repo).** 3.0 adds
  `if ($level > $config->get('severity_level')) return;` and ships **no update hook**. If the
  key is missing, PHP 8 compares `int > null` as booleans, so **every level except EMERGENCY is
  dropped**, with no error. **Do:** add `severity_level: 7` to
  `config/sync/log_stdout.settings.yml` in the same PR. On usa.gov, a run without the key printed
  only the EMERGENCY line, which proved the config line matters.
- **Don't confuse Drush's console lines with log_stdout's output.** When a test runs through
  `drush php:eval`, Drush's own logger prints coloured `[error]`/`[warning]`/`[notice]` lines,
  and at default verbosity it **stops at NOTICE**. That made it look as if INFO and DEBUG weren't
  logged. Count only the uncoloured `[drupal …]` lines (or add `-vvv`).
- **Post-updates can migrate config.** content_lock 3.0 merged its `content_lock_timeout`
  submodule into itself and uninstalled it, converting the setting. **Do:** always run
  `drush updb` **before** `drush cim`, then `drush cex` and review the diff before committing.
  Test the upgrade path from a **fresh copy of the previous release's database**, not one that
  was already upgraded on a branch. Make sure the deploy bootstrap runs `updb` before `cim`.
- **If you can't reproduce the bug a patch fixed, port the patch rather than drop it.** Also
  prove what it still does, by running a test with part of it removed.

## 6. Custom-code traps (upgrade_status didn't report these)
- **`ConfigFormBase` subclasses must pass `$typedConfigManager`** to `parent::__construct()`;
  the old form is deprecated since 10.2. Inject `config.typed`. Check
  `dg_autologout`'s `AutologoutSettingsForm` here.
- **`DependencySerializationTrait` with `private` properties** fails in D11. Change them to
  `protected`. Run a serialize round-trip on each affected class. Loggers created with
  `logger.factory->get()` can't be serialized; use `FormBase::getLogger()`.
- **Twig `spaceless`** (deprecated in Twig 3.12, removed in Twig 4; **not** a D11 blocker,
  because 11.4 still uses Twig 3).
  - Whitespace control (`{%-`, `-%}`) only trims whitespace in the **template source**. It can't
    remove whitespace inside a value's rendered output.
  - Where the whitespace comes from rendered field markup, `{{ field|render|trim|raw }}`
    reproduces `spaceless` exactly. `raw` is needed because `trim` turns markup into a plain
    string, and it's safe here because the value is already-rendered field markup.
  - For plain-string `{% set %}` captures (this repo's case), `|render|trim` may be enough.
  - Watch indentation: a `{# comment #}` on its own indented line adds that indentation to the
    output.
  - **Always confirm the output is byte-identical.**
- **`attach_library('name')` without the extension prefix** is invalid. Use
  `attach_library('theme/name')`.
- **`core_version_requirement`** must include `^11` for every custom module and theme.

## 7. Composer and lockfile hygiene
- **A newer Composer adds noise to the lock.** If the Composer that writes the lock is newer
  than the team's, the lock diff also gets `"published-time"` entries and a
  `"plugin-api-version"` bump. Keep the diff to the changed package's entry plus
  `"content-hash"`, and revert the rest.
- **Parallel PRs conflict only on `content-hash`.** To fix it, take either side, run
  `composer update --lock` to compute the correct hash, put back the lock you took, and change
  **only** the hash line. Then `composer validate` must not warn that the lock is out of date.
- **Don't `composer reinstall` a package that has patches** (composer-patches 1.x). The plugin
  deletes the package, and then the reinstall fails, leaving `web/core` (or the module) **gone**.
  `composer install` restores it. Changing a patch list makes the plugin re-patch on the next
  `composer install` anyway.
- **Changing the patch list changes `content-hash`**, because `extra` is part of the hash.
  Regenerate it as above.

## 8. Git and PR workflow
- Merge `develop` into a feature branch only after checking what the merge brings in:
  `git merge-base`, plus `git log base..develop -- <your files>`. If the branch changed only
  files `develop` never touched, the merge can't conflict.
- A commit-msg hook may add the branch prefix to commit messages. If so, don't write it again in
  the subject.
- Mnemonic diff prefixes (`i/`, `w/`) can leak into generated patches. Generate patches with
  `git diff --src-prefix=a/ --dst-prefix=b/`.
- `gh pr edit` can fail on GitHub's deprecated "Projects (classic)" API. Update the PR body
  through REST instead: `gh api -X PATCH repos/<org>/<repo>/pulls/<n> -F body=@file.md`.

## 9. Review lessons: why the first verification wasn't enough
usa.gov's first "byte-identical on 57 pages" check of the active-trail change **missed two
regressions** that a reviewer found with a better sample:
1. **Pages whose only menu link is disabled** (error and thank-you pages) lost their breadcrumb
   and sidebar.
2. **A Drush CSV export** (`usapubcsv`) builds breadcrumbs **per node, not for the current
   route**. 852 of 1,628 rows changed. The export runs after every Tome static build.

**Do:**
- Choose the sample by **edge class**, not at random. Include every node in each relevant
  edge class (for example multi-link nodes and disabled links), the front pages, and a seeded
  random sample of ordinary pages.
- Find **every consumer** of the behaviour you're changing, including Drush commands, static
  builds, exports and APIs, and diff their output as well.
- Expect fixes to interact. On usa.gov, the disabled-link fallback then made the front page
  pick a hidden `<front>` "Home" link, until the fallback was limited to the route's own links.
  Re-run the full comparison after every fix.
- Use a **negative control**: run the test where it should fail, to show it actually detects
  the problem.
