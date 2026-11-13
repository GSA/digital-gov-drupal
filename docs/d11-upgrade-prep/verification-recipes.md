# Verification recipes (Lando)

These were adapted from the commands used on usa.gov, which used Docker Compose there. They
assume:
- the Lando app `digitalgov` is running;
- the site is at `http://digitalgov.lndo.site` (`DRUSH_OPTIONS_URI` in `.lando.local.yml`);
- `lando drush` works.

Keep scratch files **outside the repo** (for example `$S=/tmp/d11-check`) so nothing gets
committed by accident.

```bash
S=/tmp/d11-check; mkdir -p $S
BASE=http://digitalgov.lndo.site
```

## 1. Blockers and target version
```bash
# Latest 11.4.x (and 11.5) releases
curl -s https://repo.packagist.org/p2/drupal/core.json | jq -r '.packages["drupal/core"][].version' | grep -E '^11\.[45]\.' | head
# s3fs's core band on its latest 3.x releases: the target must fall inside it
curl -s https://packages.drupal.org/files/packages/8/p2/drupal/s3fs.json \
  | jq -r '.packages["drupal/s3fs"][] | select(.version|test("^3\\.")) | "\(.version) \(.require["drupal/core"])"' | head -3
# Live blocker list (first-level lines = contrib blockers; Symfony lines resolve at the bump)
lando composer prohibits drupal/core 11.4.11
```

Semver scan of every locked package's core constraint. This is more reliable than reading the
constraints, because it handles bands like s3fs's correctly.
```bash
jq -r '.packages[] | select(.require["drupal/core"] != null) | "\(.name)\t\(.version)\t\(.require["drupal/core"])"' composer.lock > $S/core_reqs.tsv
lando php -r 'require "vendor/autoload.php"; use Composer\Semver\Semver;
foreach (file("php://stdin", FILE_IGNORE_NEW_LINES) as $l) { [$n,$v,$c] = explode("\t", $l);
  if (!Semver::satisfies("11.4.11", $c)) echo "$n $v [$c] d10:", Semver::satisfies("10.6.20", $c) ? "ok" : "NO", "\n"; }' < $S/core_reqs.tsv
# expect (2026-11-13): drupal/core-recommended and drupal/log_stdout only
```
(This scan was run with a local PHP, not through Lando. If `lando php` doesn't pass stdin
through, run the same `php -r` from `lando ssh`, from `/app`.)
Can a blocker be upgraded on D10? Check its target release's core constraint:
```bash
curl -s https://packages.drupal.org/files/packages/8/p2/drupal/log_stdout.json | jq -r '.packages["drupal/log_stdout"][0] | "\(.version) \(.require["drupal/core"])"'
```

## 2. Dry-run patches against target sources
```bash
cd $S && git clone -q --depth 1 --branch 11.4.11 https://github.com/drupal/core.git core
git clone -q --depth 1 --branch 11.4.11 https://github.com/drupal/core-composer-scaffold.git scaffold
# Core patches use a/core/... paths, and the drupal/core repo root is core/, so use -p2
curl -sL -o 2916377.patch https://www.drupal.org/files/issues/2024-11-11/2916377-53.patch
(cd core && patch -p2 --dry-run < ../2916377.patch)     # 2026-11-13: hunk 2 FAILS (context drift)
(cd scaffold && patch -p1 --dry-run < /path/to/repo/patches/drupal.core-composer-scaffold.implicit-drupal-core-disable.patch)
```
To rebase a patch:
1. Edit the files in a throwaway git checkout of the target sources.
2. Generate the patch with
   `git diff --src-prefix=a/core/ --dst-prefix=b/core/ > patches/<name>_d11.patch`.
   (Use `--src-prefix=a/ --dst-prefix=b/` for contrib.)
3. Dry-run it again on a fresh copy, with no fuzz and no offsets.
4. Run `php -l` on each patched file.

Keep the new file unreferenced until the core bump.

## 3. Byte-level page comparison against `develop`
**Sample by edge class.** Generate the path list with Drush, and include the front page, every
node of each affected kind, and a **seeded** random sample of ordinary pages. Template (adjust
the queries to the change being tested):
```bash
cat > $S/paths.php <<'EOF'
<?php
$storage = \Drupal::entityTypeManager()->getStorage('node');
$paths = ['/'];
// Example edge class: every published node of the affected bundle(s).
$ids = $storage->getQuery()->accessCheck(FALSE)->condition('status', 1)->condition('type', ['news', 'short_post'], 'IN')->execute();
// Seeded random sample of everything else.
mt_srand(2026);
$all = $storage->getQuery()->accessCheck(FALSE)->condition('status', 1)->execute();
$ids += array_intersect_key($all, array_flip((array) array_rand($all, min(60, count($all)))));
foreach ($storage->loadMultiple($ids) as $n) { $paths[] = $n->toUrl()->toString(); }
echo implode("\n", array_unique($paths)), "\n";
EOF
lando drush php:eval "$(tail -n +2 $S/paths.php)" > $S/paths.txt
```

Render each path and normalize what changes on every request or cache rebuild:
```bash
cat > $S/render.sh <<'EOF'
#!/bin/bash
# Usage: render.sh <paths-file> <out-dir> [cookie-jar]. Saves normalized HTML; prints "status path".
BASE=${BASE:-http://digitalgov.lndo.site}; mkdir -p "$2"
while read -r p; do
  f="$2/$(echo "$p" | sed 's|^/||; s|/|__|g; s|^$|front|').html"
  code=$(curl -s ${3:+-b "$3"} -o "$f" -w '%{http_code}' "$BASE$p")
  sed -i -E 's/\?[a-z0-9]{6}"/?CB"/g; s/js-view-dom-id-[0-9a-f]{64}/js-view-dom-id-X/g;
    s/"view_dom_id":"[0-9a-f]{64}"/"view_dom_id":"X"/g; s/form_token" value="[^"]*"/form_token" value="X"/g;
    s/form-[A-Za-z0-9_-]{43}/form-X/g; s/token=[A-Za-z0-9_-]+/token=X/g; s/"cookie_lifetime":[0-9]+/"cookie_lifetime":X/g' "$f"
  echo "$code $p"
done < "$1"
EOF
chmod +x $S/render.sh
```
The steps:
1. On `develop`: `lando drush cr`, then run `render.sh paths.txt $S/before` **twice**, into
   `before` and `before2`. `diff -rq` between them must be empty, which proves there's no noise
   left to normalize. If it isn't empty, add another `sed` rule.
2. On the branch: `lando composer install && lando drush updb -y && lando drush cim -y &&
   lando drush cr`, then render into `$S/after` with the **same** `paths.txt`.
3. Run `diff -rq $S/before $S/after`. The expected result is empty, or exactly the intended
   change.

Pages that need a login: get a one-time link, then reuse the session cookie.
```bash
uli=$(lando drush uli --uid=1 --no-browser | tr -d '\r'); jar=$S/jar.txt
curl -s -c $jar -b $jar -L -o /dev/null "$uli"
$S/render.sh $S/admin_paths.txt $S/admin_before $jar
```

## 4. Diff other consumers, not just pages
Any Drush command, export or static build that uses the behaviour you changed must also be
compared. On usa.gov, a per-node CSV export caught a regression that the page diffs missed.
```bash
lando drush <export-command> /tmp/out.csv && lando ssh -c 'cat /tmp/out.csv' > $S/before.csv   # repeat on branch → after.csv
cmp $S/before.csv $S/after.csv && echo identical
```
For the Tome static build, build on `develop` and on the branch, then run `diff -r` on the two
output directories, using the same normalization as above.

## 5. Logging check (log_stdout upgrade)
```bash
lando drush php:eval 'foreach (["emergency","alert","critical","error","warning","notice","info","debug"] as $l) \Drupal::logger("d11_check")->$l("level @l", ["@l" => $l]);' > $S/log.out 2> $S/log.err
grep -c d11_check $S/log.err   # expect 5 (EMERGENCY..WARNING) with use_stderr: '1'
grep -c d11_check $S/log.out   # expect 3 (NOTICE..DEBUG)
```
Count only the uncoloured `[drupal "base_url":…]` lines. Drush's own coloured lines stop at
NOTICE unless you pass `-v`. Run the check on `develop` and on the branch, and diff the outputs
after removing the `"date"` field. To confirm the `severity_level` trap, run
`lando drush cset log_stdout.settings severity_level --input-format=yaml null` on the branch:
only EMERGENCY should print. Then run `lando drush cim -y` to restore it.

## 6. Browser checks with one-time logins (Cypress pattern)
If the team has Cypress (or Playwright) set up, write a **scratch spec outside the repo** and
mount or copy it in. Pass one-time login links as `CYPRESS_*` environment variables, generated
with `drush uli --uri=<host the browser uses>`. Lessons from usa.gov:
- A login link is invalidated once that user logs in, so each test needs a **different user**.
- A third fresh login within one run failed for reasons we didn't track down. Run that scenario
  as a separate spec.
- Run each scenario on `develop`, on the branch, **and** on a negative control (the change
  partly removed), so you know the test detects the behaviour.

## 7. Config and Composer checks before every PR
```bash
lando drush config:status                    # expect: No differences between DB and sync directory
lando composer validate --no-check-publish   # must not warn that the lock file is out of date
git diff develop -- composer.lock | grep -E '^[-+].*("published-time"|"plugin-api-version")'   # expect: nothing
lando composer prohibits drupal/core 11.4.11 # the blocker list should shrink as tickets land
```
After a lock content-hash conflict:
1. Run `git checkout --theirs composer.lock` and `lando composer update --lock`.
2. Note the new `content-hash`.
3. Restore the lock you took, change only that hash line, and run `composer validate`.
