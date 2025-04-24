# Migration Instructions

Migrations use this [PR](https://github.com/GSA/digitalgov.gov/pull/8254) as a [source](https://federalist-466b7d92-5da1-4208-974f-d61fd4348571.sites.pages.cloud.gov/preview/gsa/digitalgov.gov/nl-json-endpoints). If you need to make changes to the source data, or you want to use your local, check out that branch and `./start_migrate.sh`. Then change the URLs to your local URLs using the IP version, localhost won't work because Drupal is running in a container.

> IMPORTANT: Post-launch, the digital_gov_migration module is disabled by default to prevent running the migrations and
> overwriting content on the site. If you need to run the migrations locally, you must enable the module.
>
> `drush.sh pm:en digital_gov_migration`
>
> Don't forget to disable it when you're done.
>
> `drush.sh pm:uninstall digital_gov_migration`

## Delete sample content that is not needed before migrating

If this is not done, then duplicate content and sample content will stick around.

`./drush.sh rcbm`

## Migrate all

`./drush.sh migrate:import --all`

## Rollback all

`./drush.sh migrate:rollback --all`

## Migrate content migrations

Drupal won't get the order right in all environments.

```
./drush.sh migrate:import --tag "digitalgov"
./drush.sh migrate:import --tag "digitalgov-guidenav"
```

## Rollback content migrations

```
./drush.sh migrate:rollback --tag "digitalgov"
./drush.sh migrate:rollback --tag "digitalgov-guidenav"
```

## Migrate a single

`./drush.sh migrate:import <migration-id>`

However, if you want to clear cache so your changes to the migration definition take place, and roll back, then use

`./migrate.sh <migration-id>`.

This is handy when developing. This script also allows passing arguments to the migration command, so you can do things like

`./migrate.sh json_images --limit=5`

So you don't have to migrate everything.

## Clean up migrated content

Fix short codes and add link it markup:

```
./drush.sh digitalgov:update-nodes
./drush.sh digitalgov:update-paragraphs
```

## Migrate all content

Do all of the above at once.

```
./migrate-all.sh
```
