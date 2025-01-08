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

## Environments and Git branches
List of development environments and their equivalent Git branches.

| **Static**        | **CMS**            | **Cloud.gov environments** | **Git branch** | **Use case**                                             |
|-------------------|--------------------|----------------------------|----------------|----------------------------------------------------------|
| drupal-gov-static-dev.app.cloud.gov  | drupal-gov-drupal-dev.app.cloud.gov   | dev            | develop            | App work that is ready for testing in cloud.gov          |
| drupal-gov-static-staging.app.cloud.gov  | drupal-gov-drupal-staging.app.cloud.gov   | staging            | stage            | All work that is ready for release/UAT testing          |
| drupal-gov-static-prod.app.cloud.gov  | drupal-gov-drupal-prod.app.cloud.gov   | prod            | main            | All work that is approved and released          |


