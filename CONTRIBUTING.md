# Contributing Guidelines

### Contents

- [Git Configuration](#git-configuration)
- [Validation](#validation)


## Git Configuration

To have your commits merged in GitHub, you must have [verified commits](https://docs.github.com/en/authentication/managing-commit-signature-verification/about-commit-signature-verification#ssh-commit-signature-verification). If you forget to do this for a MR, you will need to rebase/replay your commits.

## Validation

 * Uses RoboValidate to run the various validations.
 * Can be run manually locally via: `./robo.sh validate:all`
   * Twig Validation and PHPStan are not run (yet, but soon) when `./robo.sh validate:all` is run, run them manually via: `vendor/bin/twig-cs-fixer lint` and `vendor/bin/phpstan --memory-limit=-1`.
 * Is run when any branch is pushed to GitHub via GitHub Actions. Validation on Git commits is only run remotely when a pull request is made so that only new commits are checked.

### Branch Names

All branches created towards tasks should be in the form `feature/DIGITAL-X-Y`. `X` is the Jira ticket number and `Y` is a short description in lower case separated by dashes.

### Commits

Commit messages must be in the form: `DIGITAL-X:YZ`. `X` is the Jira ticket number, `Y` is a space and `Z` is a short description of the work done.

### Coding Standards

See the [coding standards](https://www.drupal.org/docs/develop/standards) documentation for Drupal. The project validates against the `Drupal` and `DrupalPractice` documentation.

#### IDE

[Enable coding standards help in your IDE](https://www.drupal.org/docs/extending-drupal/contributed-modules/contributed-module-documentation/coder/installing-coder#s-ide-and-editor-configuration) so you're not surprised by a bunch of errors when you push up.
