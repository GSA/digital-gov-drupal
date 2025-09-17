# Backend
This site is built using Drupal and combination of modules and themes.

## Drupal
As of the writing of this document the foundation of the site is built using Drupal + Symphony + Composer. Drupal documentation can be found here: https://www.drupal.org/docs. This site follows Drupal coding standards and best practices.

### Exporting Content as Configuration

The content for development is created via the [Default Content](https://www.drupal.org/project/default_content) module.

How do I install the content?

Content is created from the config stored at `web/modules/custom/default_content_config/content` when the site is installed (`lando si`).

How do I create more content?

Simply edit or add new content, then run `./robo.sh export-content`

:exclamation: Make sure that only content you meant to edit or add is exported. The default content module is not perfect, it can get confused with things like files and users.

### Exporting the Static Site

To test the static site generation locally please run `./robo.sh static`.

### Auto Logout

The autologout module will log you out after 30 minutes of inactivity or after 12 hours regardless of activity. This can get annoying when developing locally and having multiple tabs open.

To disable this, add the following to your `settings.local.php`:

```
/**
 * Disable autologout from running.
 */
$config['autologout.settings']['enabled'] = FALSE;
$config['dg_autologout.settings']['enabled'] = FALSE;
```

### Single Sign On

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

### Drupal & Module Discovering Available Updates via Composer
Part of managing Drupal is keeping Drupal Core and Modules updated with latest versions to help alleviate potential security issues as well as providing users with the best experience offered.

To perform a simple audit of available updates you can use `composer outdated "drupal/*"` to see what updates are available by referring to the section, "Direct dependencies required in composer.json" located at the top of the output from the issued command. These are modules/packages which we have specifically required as part of our project. The other listings under the section, "Transitive dependencies not required in composer.json" are dependencies added via our required modules.

If you ever need to track where a "Transitive dependency" is coming from you can issue the command `composer why {project/package}`. From there you will be given the package(s) which require this dependency.

#### Updating Dependencies

##### Ensure that your local is OK to destroy:

`git status`

If you are working on something right now:
`git stash && lando db-export backup.sql`

When finished updating dependencies:
`git checkout feature/my-old-branch && git stash pop && lando db-import backup.sql`

##### Updating Composer Dependencies
```
# Getting your environment in an 'Original' state with no changes.
git fetch
git checkout develop
git reset --hard origin/develop
lando rebuild -y
lando si
# Create a new feature branch for the changes.
git checkout -b feature/DIGITAL-[TICKET-NUMBER]-update-dependencies
# Update all dependencies
./composer.sh update
# OR update just Drupal core
./composer.sh update drupal/core-* -W
# Run any new update hooks, important because they can alter configuration.
./drush.sh updb -y
# Export any changes to configuration from update hooks.
./drush.sh cex -y
```

Finally, use `git status` and `git diff {file_name}` to reveal and review both file and configuration changes before committing them to your branch.

Commit the changes to composer.* and any config files updated from database updates.

The next step is to run scaffolding:

`./robo.sh drupal-env:scaffold-all`

Not everything in here needs to be committed. Somethings that will show as updates will be the overrides added in the past. Make sure to revert any changes that were not intended.

Commit the scaffolding changes.

The final step is to run validation. This is important as part of the dependency updates might be new coding standards rules that will need to be fixed.

`./robo.sh validate:all`

Fix any validation errors and commit.

`git push origin`

## Fixing Merge Conflicts with Composer

If, when rebasing or merging the `develop` branch, you get conflicts with composer.lock the composer.log file will help you replay your changes.

When the merge conflict occurs:

* `git checkout origin/develop -- composer.*` to get the composer files as in develop.
* `./composer.sh install`
* Then you can replay the composer commands you wanted to make before.

## Modules
Modules are located in `/web/modules/` directory. Each module has an module page located on https://www.drupal.org/project/project_module. The modules page include documentation, versions, change details and an issue queue. Also most modules contain additional details in a README file in the module root.

### Installing modules via Composer
To add modules, use the Composer `require` command. For example, to add the **Admin Toolbar** module:

`./composer.sh require drupal/admin_toolbar`

This will download the module and ensure it is included in your `composer.json` file, allowing it to be version-controlled and managed by Composer. Additionally this will update your `composer.lock` file which will reflect the details of installed packages and dependencies as it relates to the module being installed. In addition, a custom file called `composer.log` will have a new line added to it. This file will reflect the composer command you made. This is helpful to let others know what changes you made and to replay them in the case of conflicts. These changes will, again, require you to commit the files to the repository once testing has been done locally.

### Updating modules via Composer
To update a specific module, for example, **Admin Toolbar**:

`./composer update drupal/admin_toolbar`

This ensures that both the module and its dependencies are updated according to Drupal's compatibility guidelines.

Once updated, the following drush command should be issued, `./drush.sh updatedb && ./drush.sh cr`. This will check for any pending database updates followed up by a clearing of the cache.

Run `./drush.sh cex`, to export and review any related configuration changes that is related to the module. Updates could affect other configurations such as field settings or other aspects of the site, so review carefully, test, and verify that the changes are valid.

Finally, use `git status` and `git diff {config_file.yml}` to reveal and review configuration changes that are located in `config/...` directory before committing them to your branch.

### Contrib
Included here are some of the non-standard Drupal contrib modules and their use below. To see all the modules in the system review the modules dashboard page located at `/admin/modules`. These modules are maintained by the Drupal community and have regular updates for enhancements and security patches.

#### Autologout
Fulfills security requirement to log user out when inactive for a designated period of time.

#### Config ignore & Config split
Modules that allow organization/modification of application configuration per environment.

#### Default content
Allows exporting content as configuration so that developers do not need a 'shared database'.

#### External auth & OpenID Connect
Fulfills security requirement to provide SSO integration configuration.

#### Embedded content
Adds a button to the WYSIWYG to embed configurable and themable non-reusable data structures. These were the 'shortcodes' from the Hugo site.

#### Link class
Allows site builders to add classes to a link field.

#### Log stdout
Fulfills security requirement to send Drupal log messages to the stdout for Cloud.gov.

#### Maxlength
Adds a max length to WYSIWYG fields that just counts text while letting tags that don't provide length to be counted.

#### Migrate plus & Migrate tools
Provides additional migration function for migration scripts.

#### Menu admin per menu
Allows access to individual menus to edit instead of giving all.

#### Multivalue form element
Allows you to give group fields together and add additional values. Very handy so that custom fields are not required when a field needs multiple pieces of data.

#### No Request New Password
Disables the the page to request a new password.

#### Override Node options
Editors cannot edit the author / created fields or publish a node without getting the 'administer content' permission. This allows giving this functionality with individual permissions.

#### Paragraph View Mode
Allow the same paragraph to be displayed differently.

#### Remove Username
Removes the user entity's user name field and makes the email field take its place.

#### Role delegation
Allows a user to assign some but not all roles.

#### S3 file system
Adds connection to S3 file system in Cloud.gov.

#### Scheduler
Allows content to be scheduled for (un)publishing.

#### Security Kit
Allows providing headers for security requirements.

#### Tome
Provides static site generation for the Drupal site.

#### Userprotect
Normally users can update their email / password. However, this site is all SSO, so this should be disallowed.

### Custom
Below is a list of custom modules created for use on Digital.gov. These modules can be found in the codebase at `/web/modules/custom`. These modules are maintained by project developers and need to be re-evaulated for each Drupal upgrade.

#### Convert Text
Handles the conversion of Markdown to HTML.

#### Default content config
Handles default content hooks and where the default content configuration is stored.

#### DG Autologout
A duplicate of the Autologout module so that users could be logged out for inactivity and a specific time.

#### DG Breadcrumb
Alters core breadcrumb functionality.

#### DG Fields
Providing for and allowing for altering fields and formatters.

#### DG Token
Alters token functionality.

#### Embedded Content Shortcodes
Provides embedded content plugins.

#### Embedded Content - USWDS
Provides USWDS components for Ckeditor5 embedded content.

## Module Patches
Review the patches in `composer.patches.json` and look at the `/patches/` directory at the root. These patches need to be re-evaluated when the original module gets updated to determine if the work has been included in the latest release or if the patch needs to be rerolled.

## Repositories
In addition to Module Patches, it is worth reviewing the `repositories` section of the composer.json file. Here we can choose/define where a package is installed from (its source code). This can be used to reference another source which could serve as an alternative to the project's public main repository. So three may be instances where this section will need to be updated to add or remove a repository source for a given module or package.

## Database - Mysql
The site utilizes Mysql for its database.

### Limitations
Through its implementation via Cloud.gov there are limitations over what is configurable for Mysql.

#### Setting the MySQL transaction isolation level
Issue: The recommended database transaction isolation level is READ COMMITTED vs REPEATABLE READ.
Description: In addition to being unable to configure Mysql, the alternate solution of setting the isolation level via the database configuration within the settings.php file is not a recommended approach as it sets the isolation level upon each page load which isn't optimal.
Impact: Low
Source: https://www.drupal.org/docs/getting-started/system-requirements/setting-the-mysql-transaction-isolation-level#s-other-methods-to-change-the-transaction-isolation-level
