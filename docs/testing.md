# QA & Testing

## Testing with Drupal
With a Drupal CMS there are several aspects of testing that need to be covered.

There are test accounts already created with the different roles that are available.

Each of these roles has different access levels on the site and we need to check to ensure that they still function as expected.

If a feature has any portion that will reflect on the front-facing site, then you must test the functionality on the static version of the site. To do so, please run `./robo.sh static`. This will export the site and start an HTTP server with the static version of the site.
