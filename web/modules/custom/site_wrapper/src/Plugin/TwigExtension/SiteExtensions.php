<?php

declare(strict_types=1);

namespace Drupal\site_wrapper\Plugin\TwigExtension;

use Twig\Extension\AbstractExtension;
use Twig\TwigFunction;

/**
 * Adds custom twig functions and filters for use by themes.
 */
class SiteExtensions extends AbstractExtension {

  /**
   * Declare custom twig function.
   *
   * @return \Twig\TwigFunction[]
   *   TwigFunction array.
   */
  public function getFunctions() {
    return [
      new TwigFunction('dg_logo_source', [$this, 'getLogoSource']),
    ];
  }

  /**
   * Returns the logo image to use for a given URL's host/domain.
   *
   * USAGE:
   *    {{ dl_logo_url(my_url, '/' ~ active_theme_path()) }
   */
  public function getLogoSource(string $uri, string $active_theme_path): string {
    $host = parse_url($uri, PHP_URL_HOST);

    if (!$host) {
      // Assume a local URL.
      return $active_theme_path . '/static/digitalgov/img/digit-50.png';
    }

    // This is not a foolproof way to get domains.
    $domain = preg_replace('@^(?:.+?\\.)+(.+?\\.(?:co\\.uk|com|net|org|gov|mil|io))@', '$1', $host);

    if ($domain === 'digital.gov') {
      return $active_theme_path . '/digitalgov/img/digit-50.png';
    }

    return 'https://www.google.com/s2/favicons?domain=' . $domain;
  }

}
