# Contributing Guidelines

### Contents

- [Getting Starting](#getting-starting)
- [Git](#git)
- [Content](#content)
- [Validation](#validation)

## Getting Started

To get started with a local environment, please see the Wiki for the [Drupal Env Lando](https://github.com/mattsqd/drupal-env-lando/wiki) project.

TLDR:
* This is just a lando site, all lando commands are available.
* First time: `./robo.sh lando:init`
* Starting Lando: `lando start`
* Installing a Drupal site from config (no DB needed): `lando si`
* See a list of shortcuts (Drush, Composer, etc.): `./robo.sh common:shortcuts-help`
* Make sure that you use `./composer.sh` instead of `composer` or `lando composer`. `./composer.sh` will cause entries `composer.log` to be made so we can replay composer commands on conflicts.
* Sign in as admin: `./drush uli`

## Git

To have your commits merged in GitHub, you must have [verified commits](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification#ssh-commit-signature-verification). If you forget to do this for a MR, you will need to rebase/replay your commits.

## Content

The content for development is created via the [Default Content](https://www.drupal.org/project/default_content) module.

How do I install the content?

Content is created from the config stored at `web/modules/custom/default_content_config/content` when the site is installed.

How do I create more content?

Simply edit or add new content, then run `./robo.sh drupal-project:export-content`

:exclamation: Make sure that only content you meant to edit or add is exported. The default content module is not perfect, it can get confused with things like files and users.

## Validation

 * Uses [RoboValidate](https://github.com/mattsqd/robovalidate) to run the various validations.
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
