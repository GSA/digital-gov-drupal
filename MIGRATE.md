# Migration Instructions

Migrations use this [PR](https://github.com/GSA/digitalgov.gov/pull/8254) as a [source](https://federalist-466b7d92-5da1-4208-974f-d61fd4348571.sites.pages.cloud.gov/preview/gsa/digitalgov.gov/nl-json-endpoints). If you need to make changes to the source data or you want to use your local, check out that branch and `./start_migrate.sh`. Then change the URLs to your local URLs using the IP version, localhost won't work because Drupal is running in a container.

## Migrate all

`./drush.sh migrate:import --all`


## Rollback all

`./drush.sh migrate:rollback --all`

## Migrate content migrations

`./drush.sh migrate:import --tag "digitalgov"`

## Rollback content migrations

`./drush.sh migrate:rollback --tag "digitalgov"`

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
