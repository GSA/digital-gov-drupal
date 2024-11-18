# Contributing Guidelines

### Contents

- [Getting Starting](#getting-starting)
- [Git](#git)
- [Content](#content)
- [Validation](#validation)
- [Updating Dependencies](#updating-dependencies)

## Software Requirements

* PHP 8.3: Used to run `./robo.sh` / `./composer.sh` tasks
* Composer Version 2: https://getcomposer.org/, much faster to run composer locally than through docker.
* Lando: https://lando.dev/download/

## Getting Started

* This is just a lando site, all lando commands are available.
* First time: `./robo.sh lando:init`
* Starting Lando: `lando start`
* Installing a Drupal site from config (no DB needed): `lando si`
* If switching to a new branch, always: `lando rebuild -y && lando si` to start off completely fresh.
* See a list of shortcuts (Drush, Composer, etc.): `./robo.sh common:shortcuts-help`
* Use `./composer.sh` instead of `composer` or `lando composer`. `./composer.sh` will cause entries `composer.log` to be made so we can replay composer commands on conflicts.
* Sign in as admin: `./drush uli`

## Git

To have your commits merged in GitHub, you must have [verified commits](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification#ssh-commit-signature-verification). If you forget to do this for a MR, you will need to rebase/replay your commits.

## Content

The content for development is created via the [Default Content](https://www.drupal.org/project/default_content) module.

How do I install the content?

Content is created from the config stored at `web/modules/custom/default_content_config/content` when the site is installed (`lando si`).

How do I create more content?

Simply edit or add new content, then run `./robo.sh drupal-project:export-content`

:exclamation: Make sure that only content you meant to edit or add is exported. The default content module is not perfect, it can get confused with things like files and users.

## Validation

 * Uses RoboValidate to run the various validations.
 * Can be run manually locally via: `./robo.sh validate:all`
 * Is run when any branch is pushed to GitHub via GitHub Actions. Validation on Git commits is only run remotely when a pull request is made so that only new commits are checked.

### Branch Names

All branches created towards tasks should be in the form `feature/DIGITAL-X-Y`. `X` is the Jira ticket number and `Y` is a short description in lower case separated by dashes.

### Commits

Commit messages must be in the form: `DIGITAL-X:YZ`. `X` is the Jira ticket number, `Y` is a space and `Z` is a short description of the work done.

### Coding Standards

See the [coding standards](https://www.drupal.org/docs/develop/standards) documentation for Drupal. The project validates against the `Drupal` and `DrupalPractice` documentation.

#### IDE

[Enable coding standards help in your IDE](https://www.drupal.org/docs/extending-drupal/contributed-modules/contributed-module-documentation/coder/installing-coder#s-ide-and-editor-configuration) so you're not surprised by a bunch of errors when you push up.

## Updating Dependencies

### Ensure that your local is OK to destroy:

`git status`

If you are working on something right now:
`git stash && lando db-export backup.sql`

When finished updating dependencies:
`git checkout feature/my-old-branch && git stash pop && lando db-import backup.sql`

### Updating
```
git fetch
git checkout develop
git reset --hard origin/develop
lando rebuild -y
lando si
git checkout -b feature/DIGITAL-[TICKET-NUMBER]-update-dependencies
./composer.sh update
./drush.sh updb -y
./drush.sh cex -y
```

Commit the changes to composer.* and any config files updated from database updates.

The next step is to run scaffolding:

`./robo.sh drupal-env:scaffold-all`

Not everything in here needs to be committed. Somethings that will show as updates will be the overrides added in the past. Make sure to revert any changes that were not intended.

Commit the scaffolding changes.

The final step is to run validation. This is important as part of the dependency updates might be new coding standards rules that will need to be fixed.

`./robo.sh validate:all`

Fix any validation errors and commit.

`git push origin`
