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
      new TwigFunction('dg_lookup_favicon', [$this, 'lookupFavicon']),
    ];
  }

  /**
   * Returns the logo image to use for a given URL's host/domain.
   *
   * This method falls back to a local logo for digital.gov domains.
   *
   * USAGE:
   *    {{ dl_logo_url(my_url, '/' ~ active_theme_path()) }
   */
  public function getLogoSource(string $uri, string $active_theme_path): string {
    $host = parse_url($uri, PHP_URL_HOST);

    if (!$host || $host === 'digital.gov' || str_contains($host, '.digital.gov')) {
      // Assume a local URL.
      return $active_theme_path . '/static/digitalgov/img/logos/digit-50.png';
    }

    return self::buildFaviconSearch($uri);
  }

  /**
   * Ask google for the favicon to use for a given URL.
   *
   * USAGE:
   *    {{ lookupFavicon(my_url) }}
   */
  public function lookupFavicon(string $uri, string $active_theme_path): string {
    return self::buildFaviconSearch($uri);
  }

  /**
   * Builds the Google favicon search URI.
   */
  protected static function buildFaviconSearch(string $uri): string {
    $host = parse_url($uri, PHP_URL_HOST);

    // This is not a foolproof way to get domains.
    $domain = preg_replace('@^(?:.+?\\.)+(.+?\\.(?:co\\.uk|com|net|org|gov|mil|io))@', '$1', $host);

    return 'https://www.google.com/s2/favicons?domain=' . $domain;
  }

}
