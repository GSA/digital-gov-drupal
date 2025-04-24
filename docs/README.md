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