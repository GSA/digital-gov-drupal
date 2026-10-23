### Runbook for `downsync.yml` and `scripts/downsync.sh`

#### Introduction

Downsync copies one space's database and public files into another space, overwriting what's there. Its usual job is a downsync: refreshing `staging` or `dev` from `prod` so changes can be tested against real content. Any space can be the source or the target, but anything other than a downsync has to be confirmed separately:

| Direction | Example | To confirm, type |
| --- | --- | --- |
| Down | `prod` → `staging`, `staging` → `dev` | the target's name, e.g. `staging` |
| Up | `dev` → `staging` | `sync dev up to staging` |
| Into prod | `staging` → `prod` | `overwrite prod with staging` |

An upward sync can leave the target broken. The source usually runs newer code, so its database may already have update hooks and schema changes that the target's code doesn't expect, and `drush deploy` can't undo them.

Syncing into prod is almost never the right call. To roll prod back, use **Database Restore** and **Files Restore** from `main`. When the target is prod, it always backs prod up first and shows the warnings, even once confirmed.

It runs either as a GitHub Actions workflow or from your computer, and both do the same steps: the workflow runs `scripts/downsync.sh`. If the confirmation doesn't match, it stops before changing anything. For an upward sync or a sync into prod, it shows the warnings first.

#### Before the first run

- The GitHub Actions variable `INSTALL_DRUPAL_SPACES` must not include the target. A space listed there is reinstalled from default content on every deploy, which would throw the synced data away. The workflow checks this and stops if the target is listed. Run from your computer, it can't see the variable, so check it yourself.

#### Running it from GitHub Actions

Go to Actions → **Downsync** → **Run workflow**. The branch you run it from only supplies the scripts; the `source` and `target` inputs decide which spaces are read and overwritten.

| Input | Default | Effect |
| --- | --- | --- |
| `source` | `prod` | The space to copy from. |
| `target` | `staging` | The space to overwrite. |
| `confirm` | | See the table above. |
| `sync_database` | on | Replace the target's database. |
| `sync_files` | on | Replace the target's public files (`cms/public` in its storage bucket). Private files are left alone. |
| `use_latest_backup` | off | Copy the source's most recent backup instead of backing it up now. Prod is backed up nightly at 06:00 UTC. Dev and staging only have whatever backup was last taken there, which may be old. |
| `backup_target_first` | on | Back up the target's database and files before replacing them. Always on when the target is prod. |
| `regenerate_static` | on | Rebuild the target's static site from the new content. On prod, this publishes it. |
| `database_file_override` | | A specific dump in the source's backup bucket, e.g. `2026/10/15/2026-10-15T06-00-12Z.sql.gz`. Implies `use_latest_backup` for the database. |
| `storage_file_override` | | A specific files archive, e.g. `storage/2026/10/15/2026-10-15T06-00-12Z.tar.gz`. Implies `use_latest_backup` for files. |

To list a space's backups (replace `prod` with the space):

```bash
cf target -s prod
source ./scripts/cloud-gov-s3-creds.sh digital-gov-backup-prod
aws s3 ls "s3://${AWS_BUCKET}" --recursive
source ./scripts/cloud-gov-s3-creds.sh digital-gov-backup-prod -d
```

#### Running it from your computer

You need the AWS CLI, `jq`, the CloudFoundry CLI v8 with the `cf-service-connect` plugin, and, to sync the database, `mysql` and `mysqldump` (see [Prerequisites](../../devops.md#software)). Your Cloud.gov account needs access to both spaces. Then:

```bash
cf login -a api.fr.cloud.gov --sso
./scripts/downsync.sh -s prod -t staging
```

It prints what it's about to do, shows any warnings, and asks you to type the phrase from the table above. The options match the workflow's inputs:

| Option | Workflow input |
| --- | --- |
| `-s`, `--source SPACE` (default `prod`) | `source` |
| `-t`, `--target SPACE` (required) | `target` |
| `--database-only`, `--files-only` | `sync_files` off, `sync_database` off |
| `--use-latest-backup` | `use_latest_backup` |
| `--no-target-backup` | `backup_target_first` off |
| `--no-static` | `regenerate_static` off |
| `--database-file PATH`, `--files-file PATH` | `database_file_override`, `storage_file_override` |
| `--confirm PHRASE` | `confirm`, to run without being asked |

`-h` prints them all. A few things differ from the workflow:

- The files are downloaded to your computer and uploaded again, so syncing files can take a while on a slow connection. Everything goes in a temporary directory, which needs room for several GB and is deleted when the script exits, including when it fails or you press Ctrl-C.
- It switches `cf` between spaces as it goes, and puts it back on the space you started in when it's done.
- Nothing stops a run from your computer from overlapping one in GitHub Actions. Check the Actions tab first.

#### What it does

1. Checks the inputs and the confirmation (`downsync-preflight.sh`), then starts the bastions it needs.
2. Unless an existing backup was chosen, backs up the source's database and files to its own backup bucket (`database-backup.sh`, `files-backup.sh`).
3. If `backup_target_first` is on, backs up the target the same way.
4. Syncs the `cms/public` folder from the source's files archive into the target's storage bucket with `--delete`, skipping the regenerable `cms/public/php` cache (`files-restore.sh` with `BACKUP_SPACE` and `PUBLIC_FILES_ONLY`). Public files that only the target had are deleted.
5. Restores the source's database dump through the target's bastion (`s3-backup-download.sh` with `BACKUP_SPACE`, then `database-restore.sh`). The target's database is dropped first. A dump without mysqldump's completion marker is refused before anything is dropped.
6. On the target app, runs `drush cr`, then `orch/deploy.sh` (`drush deploy`, which applies the target branch's update hooks and config), then `drush s3fs-rc` and `drush cr` (`cloud-gov-post-sync.sh`).
7. Runs `upkeep` as a task on the target app, to regenerate the static site.
8. Stops the bastions it started, whether or not the run succeeded.

SSH stays off in prod's space except while a step needs it: it is opened for the database tunnel and the post-sync `drush` commands, and closed again even if the step fails.

Only one downsync workflow runs at a time. Nothing stops one from overlapping a run from someone's computer, a deploy, or the nightly prod backup at 06:00 UTC, which stops prod's bastion when it finishes. Avoid all three.

#### Undoing a sync

With `backup_target_first` on, the target's pre-sync database and files are its backup bucket's `latest.sql.gz` and `storage/latest.tar.gz`. To put them back, run **Database Restore** and **Files Restore** from the target's branch (`develop` for dev, `stage` for staging, `main` for prod).

Do it before anything else backs the target up. The nightly backup overwrites prod's `latest` copies at 06:00 UTC, and a later downsync using the target as its source or target does the same. The older backups stay in the bucket's dated folders; pass one with `database_file_override` or `storage_file_override`.

With `backup_target_first` off, only the backups the target already had are left, and none may hold the data just overwritten.

#### After a sync

- The target now has the source's content and user accounts. No environment sends mail (maillog's `send` is `false`).
- GSA Auth uses `auth-preprod.gsa.gov` on dev and staging and `auth.gsa.gov` on prod. With `connect_existing_users` on, an existing account is linked by email the first time its owner logs in, so each person needs an account with the same email on the target's GSA Auth. `drush uli` still works.
- Anything created only on the target is gone.

#### Troubleshooting

- **"confirm doesn't match"**: Run the workflow again with `confirm` set to the phrase in the message. For an upward sync or a sync into prod, read the warnings above it first.
- **"is in INSTALL_DRUPAL_SPACES"**: Remove the target from that repository variable (Settings → Secrets and variables → Actions → Variables) and run the workflow again.
- **"Dump is incomplete"**: The chosen dump is truncated. Pick an earlier dated dump with `database_file_override`. The target hasn't been changed.
- **"The import reported errors"**: The log lists mysql error codes and dump line numbers. It doesn't show the SQL, because that can be production data. The import ran to the end, but Post Sync was skipped. Inspect those lines in a local copy of the dump, or restore the pre-sync backup.
- **"Timed out waiting for the database tunnel"**: Check that the bastion app (`digital-gov-<bastion>-<space>`) is running and that SSH is allowed in the space.
- **Post Sync fails**: This is the same `drush deploy` a deploy runs, now against the source's data. Treat it like a failed deploy: the target branch's update hooks or config don't apply cleanly to what the source has. After an upward sync, this is the risk the warning described.
