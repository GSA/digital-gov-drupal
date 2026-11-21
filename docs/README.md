# Developer documentation

## Table of Contents

- [Backend](backend.md)
- [Disaster Reovery](disasterrecovery.md)
- [DevOps](devops.md)
- [Frontend](frontend.md)
- [Git standards](gitstandards.md)
- [Git workflow](gitworkflow.md)
- [QA & Testing](testing.md)
- [Releases](releases.md)
- [Release and deploy cheat sheet](#release-and-deploy-cheat-sheet) (below)

## Release and deploy cheat sheet

The quick, in-order version of a regular release (not a hotfix). See [Releases](releases.md) for the background, versioning rules and the hotfix process.

> [!IMPORTANT]
> Run `create-release` **before** you draft the GitHub release. Drafting the GitHub release first creates the tag, and `create-release` then fails because the tag already exists.

### 1. Create the release and deploy it to staging

1. Start from a clean, up-to-date `develop` branch:

   ```shell
   git fetch --all
   git checkout develop
   git pull
   ```

2. Create the release branch and tag. Check the [releases page](https://github.com/GSA/digital-gov-drupal/releases) for the last version and increment `MINOR` (versions are `MAJOR.MINOR.HOTFIX`, so a release always ends in `.0`):

   ```shell
   ./robo.sh create-release release 1.11.0
   ```

   This pushes `release/1.11.0` and the `v1.11.0` tag to GitHub.
3. The push starts the **Build and deploy** workflow, which deploys to staging. Watch it in the [Actions tab](https://github.com/GSA/digital-gov-drupal/actions).
4. When the deploy finishes, the team reviews the staging environment.

### 2. Draft the GitHub release

This is documentation only and changes nothing on the site. It's what you link to when you announce the release in Slack.

1. Go to [Releases](https://github.com/GSA/digital-gov-drupal/releases) and click **Draft a new release**.
2. Select the tag you just created (for example `v1.11.0`).
3. Click **Generate release notes**, then tidy them up. Removing entries like "Merge main into develop", tagging commits and "New contributors" is fine.
4. Check **Set as a pre-release** and save.

### 3. If staging finds a problem: update the release

Only before the release has been merged to `main`.

1. Get the fix into the release branch (`release/1.11.0`) with a PR that targets it. If `develop` hasn't moved since the release was tagged, you can instead merge the fix to `develop` as usual and then PR `develop` into the release branch. Each update to the release branch redeploys staging.
2. Re-create the tag on the updated branch (use the same arguments as `create-release`):

   ```shell
   ./robo.sh drupal-project:re-tag-release release 1.11.0
   ```

3. If you already drafted the GitHub release, edit it. **Generate release notes** appends a fresh list to the existing text, so copy over the new entries and delete the rest.

### 4. Merge to `main` and deploy to production

1. Open a **draft** PR from the release branch (`release/1.11.0`) into `main`. Keeping it a draft stops anyone merging it, and starting the prod deploy, before you're ready.
2. Get someone else to approve it.
3. Pause static site generation on prod: in **Settings > Secrets and variables > Actions > Variables**, remove `prod` from `GENERATE_STATIC_SITE_ON_CRON_SPACES`. If a "Generate Static (prod)" run is already in progress in the Actions tab, wait for it to finish. (It's scheduled at :45 past the hour, and GitHub often starts it a few minutes late.)
4. Mark the PR ready for review and merge it (use **Create a merge commit**). **Build and deploy** starts the production deploy.
5. Wait for the **whole** workflow to finish before you check the site. After the deploy step there is a post-deploy step that puts the CMS in maintenance mode, runs database updates and config import, then takes it out of maintenance mode. The site can look broken until that step completes.
6. Add `prod` back to `GENERATE_STATIC_SITE_ON_CRON_SPACES`.
7. Tell content editors the CMS is back up and they can resume editing.

> [!NOTE]
> Static site generation does not check for maintenance mode (`scripts/upkeep` runs regardless), which is why step 3 pauses it for the deploy.

### 5. Mark the GitHub release as latest

1. Open the release on the [Releases](https://github.com/GSA/digital-gov-drupal/releases) page and edit it.
2. Uncheck **Set as a pre-release**, check **Set as the latest release**, and click **Update release**.

### 6. Merge `main` back into `develop`

1. Open a PR from `main` into `develop`. This brings the release merge commit back to `develop` so the branches stay in sync.
2. Get it approved and merge it. This triggers a deploy to dev.

## Environments and Git branches
List of development environments and their equivalent Git branches.

| **Static**                                             | **CMS**                                                | **Cloud.gov Environments** | **Git branch** | **Use case**                   |
|--------------------------------------------------------|--------------------------------------------------------|----------------------------|----------------|--------------------------------|
| [digital-gov-static-dev.app.cloud.gov][static-dev]     | [digital-gov-drupal-dev.app.cloud.gov][drupal-dev]     | dev                        | develop        | Ready for testing in cloud.gov |
| [digital-gov-static-staging.app.cloud.gov][static-stg] | [digital-gov-drupal-staging.app.cloud.gov][drupal-stg] | staging                    | stage          | Ready for release/UAT testing  |
| [digital-gov-static-prod.app.cloud.gov][static-prod]   | [digital-gov-drupal-prod.app.cloud.gov][drupal-prod]   | prod                       | main           | Approved and released          |

[static-dev]: https://digital-gov-static-dev.app.cloud.gov
[drupal-dev]: https://digital-gov-drupal-dev.app.cloud.gov
[static-stg]: https://digital-gov-static-staging.app.cloud.gov
[drupal-stg]: https://digital-gov-drupal-staging.app.cloud.gov
[static-prod]: https://digital-gov-static-prod.app.cloud.gov
[drupal-prod]: https://digital-gov-drupal-prod.app.cloud.gov