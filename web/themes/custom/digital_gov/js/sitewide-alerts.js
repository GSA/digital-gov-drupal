/**
 * Add missing classes to site alert elements.
 */

Drupal.behaviors.siteAlert = {
  attach: function (context, settings) {
    once("alertA", ".dg-site-alert a", context).forEach(function (element) {
      element.classList.add("usa-link");
    });
    once("alertUl", ".dg-site-alert ul", context).forEach(function (element) {
      element.classList.add("usa-list");
    });
  },
};
