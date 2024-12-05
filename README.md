# Digital.gov (Drupal)

Welcome to the Digital.gov Drupal site.

See our [CONTRIBUTING.md](CONTRIBUTING.md).

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

`./robo.sh lando:set-env GSA_AUTH_CLIENT_SECRET`

* Visit https://digitalgov.lndo.site/user and click the login button.


