# Digital.gov (Drupal)

Welcome to the Digital.gov Drupal site.

See our [CONTRIBUTING.md](CONTRIBUTING.md) for Git configuration and working with validation.

### Contents

- [Software Requirements](#software-requirements)
- [Getting Starting](#getting-started)
- [Common Development Tasks](#common-development-tasks)

## Software Requirements

* PHP 8.3: Used to run `./robo.sh` / `./composer.sh` tasks
* Composer Version 2: https://getcomposer.org/, much faster to run composer locally than through docker
* Lando: https://lando.dev/download/

## Getting Started

The local environment is configured to use the [Lando Drupal Plugin](https://docs.lando.dev/plugins/drupal/getting-started.html). However, you cannot just `lando start` the first time you start the site. Instead, please `./robo.sh lando:init`. Following that, you can interact with the environment like a normal Lando site.

There is some custom functionality apart from what's in the base Lando installation.
* Installing a Drupal site from config (no DB needed): `lando si`
* If switching to a new branch, always: `lando rebuild -y && lando si` to start off completely fresh.
* See a list of shortcuts (Drush, Composer, etc.): `./robo.sh common:shortcuts-help`
* Use `./composer.sh` instead of `composer` or `lando composer`. `./composer.sh` will cause entries `composer.log` to be made so we can replay composer commands on conflicts.
* Sign in as admin: `./drush.sh uli`.
* Export content as configuration `./robo.sh drupal-project:export-content`. See [Exporting Content as Configuration](#exporting-content-as-configuration).

## Common Development Tasks

### Exporting Content as Configuration

The content for development is created via the [Default Content](https://www.drupal.org/project/default_content) module.

How do I install the content?

Content is created from the config stored at `web/modules/custom/default_content_config/content` when the site is installed (`lando si`).

How do I create more content?

Simply edit or add new content, then run `./robo.sh drupal-project:export-content`

:exclamation: Make sure that only content you meant to edit or add is exported. The default content module is not perfect, it can get confused with things like files and users.

## Single Sign On

The site uses GSA Auth for authentication. You can always use `./drush.sh uli` to create a one time login link.

If you would like to use SSO:

* Your account must be initialized in the pre-production GSA Auth site.

Visit https://auth-preprod.gsa.gov/ and use your normal GSA credentials to authenticate your account. Once you sign in and get to your dashboard, you can close the site.

* Your user account must exist first, SSO will never create your account.

Many users are created in default content, but if you're not in there:
```
./drush.sh user:create my.name@gsa.gov --mail=my.name@gsa.gov
./drush.sh user:role:add admin --mail=my.name@gsa.gov
```
* Only .gsa.gov emails can authenticate.
* You must use the [https version](https://digitalgov.lndo.site) of the site, http will not work.
* You must get the GSA Auth Client Secret value from another developer / lead.

To set the value run the following command then paste in the value when asked. Make sure to respond with 'yes' to rebuilding the environment:

`./robo.sh lando:set-env GSA_AUTH_KEY` (GSA_AUTH_KEY is not the value, it's the name of the env variable).

* Visit https://digitalgov.lndo.site/user and click the login button.


### Updating Dependencies

#### Ensure that your local is OK to destroy:

`git status`

If you are working on something right now:
`git stash && lando db-export backup.sql`

When finished updating dependencies:
`git checkout feature/my-old-branch && git stash pop && lando db-import backup.sql`

#### Updating Composer Dependencies
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

### Fixing Merge Conflicts with Composer

If, when rebasing or merging the `develop` branch, you get conflicts with composer.lock the composer.log file will help you replay your changes.

When the merge conflict occurs:

* `git checkout origin/develop -- composer.*` to get the composer files as in develop.
* `./composer.sh install`
* Then you can replay the composer commands you wanted to make before.
