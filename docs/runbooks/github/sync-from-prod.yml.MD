### Runbook for `sync-from-prod.yml`

#### Introduction

This workflow overwrites the `dev` or `staging` space with production's database and public files, so changes can be tested against real content. It never writes to production. It reads production's backup bucket, which `daily-backup.yml` refreshes every night at 06:00 UTC, so the copy can be up to a day old.

#### Before the first run

- The GitHub Actions variable `INSTALL_DRUPAL_SPACES` must not include the target. A space listed there is reinstalled from default content on every deploy, which would throw the synced data away. The workflow checks this and stops if the target is listed.
- The prod backup bucket must contain a files archive (`storage/latest.tar.gz`). `daily-backup.yml` writes it from DIGITAL-721 onward.

#### Running it

Go to Actions → **Sync From Prod** → **Run workflow**. The branch you run it from only supplies the scripts; the `target` input decides which space is overwritten.

| Input | Default | Effect |
| --- | --- | --- |
| `target` | `staging` | `staging` or `dev`. |
| `sync_database` | on | Replace the target's database. |
| `sync_files` | on | Replace the target's public files (`cms/public` in its storage bucket). Private files are left alone. |
| `backup_target_first` | on | Back up the target's database to its own backup bucket before replacing it. |
| `regenerate_static` | on | Rebuild the target's static site from the new content. |
| `database_file_override` | | A specific dump in the prod backup bucket, e.g. `2026/10/15/2026-10-15T06-00-12Z.sql.gz`. |
| `storage_file_override` | | A specific files archive, e.g. `storage/2026/10/15/2026-10-15T06-00-12Z.tar.gz`. |

To list the available backups (this needs access to the prod space):

```bash
cf target -s prod
source ./scripts/cloud-gov-s3-creds.sh digital-gov-backup-prod
aws s3 ls "s3://${AWS_BUCKET}" --recursive
source ./scripts/cloud-gov-s3-creds.sh digital-gov-backup-prod -d
```

#### What it does

1. Stops if the target isn't `dev` or `staging`, or is listed in `INSTALL_DRUPAL_SPACES`.
2. Optionally backs up the target's database (`database-backup.sh`).
3. Downloads prod's files archive and syncs its `cms/public` into the target's storage bucket with `--delete`, skipping the regenerable `cms/public/php` cache (`files-restore.sh` with `BACKUP_SPACE=prod` and `PUBLIC_FILES_ONLY`). Public files that only the target had are deleted.
4. Downloads prod's database dump and restores it through the target's bastion (`s3-backup-download.sh` with `BACKUP_SPACE=prod`, then `database-restore.sh`). The target's database is dropped first. A dump without mysqldump's completion marker is refused before anything is dropped.
5. On the target app, runs `drush cr`, then `orch/deploy.sh` (`drush deploy`, which applies the target branch's update hooks and config), then `drush s3fs-rc` and `drush cr` (`cloud-gov-post-sync.sh`).
6. Runs `upkeep` to regenerate the static site.

Avoid running a sync while a deploy to the same space is in progress. Nothing enforces this.

#### Undoing a sync

With `backup_target_first` on, the target's previous database is now its backup bucket's `latest.sql.gz`. To put it back, run **Database Restore** from the target's branch (`develop` for dev, `stage` for staging). If you've synced more than once since then, `latest.sql.gz` holds an earlier copy of prod instead. The older backups are in that bucket's dated folders; pass one with `database_file_override`.

Public files aren't backed up before a sync, so files that only the target had can't be recovered.

#### After a sync

- The target now has production's content and user accounts. No environment sends mail (maillog's `send` is `false`).
- On dev and staging, GSA Auth uses `auth-preprod.gsa.gov`. With `connect_existing_users` on, an existing account is linked by email the first time its owner logs in, so each person needs a preprod account with the same email. `drush uli` still works.
- Anything created only on the target is gone.

#### Troubleshooting

- **"is in INSTALL_DRUPAL_SPACES"**: Remove the target from that repository variable (Settings → Secrets and variables → Actions → Variables) and run the workflow again.
- **"Dump is incomplete"**: The chosen dump is truncated. Pick an earlier dated dump with `database_file_override`. The target hasn't been changed.
- **"The import reported errors"**: The log lists mysql error codes and dump line numbers. It doesn't show the SQL, because that is production data. The import ran to the end, but Post Sync was skipped. Inspect those lines in a local copy of the dump, or restore the pre-sync backup.
- **"Timed out waiting for the database tunnel"**: Check that the target's bastion app (`digital-gov-<bastion>-<target>`) is running and that SSH is allowed in the space.
- **Post Sync fails**: This is the same `drush deploy` a deploy runs, now against production's data. Treat it like a failed deploy: the target branch's update hooks or config don't apply cleanly to what production has.
