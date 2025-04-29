<?php

declare(strict_types=1);

namespace Drupal\site_wrapper\Plugin\TwigExtension;

use Drupal\Core\Theme\ThemeManagerInterface;
use Drupal\Core\Url;
use Twig\Extension\AbstractExtension;
use Twig\TwigFunction;

/**
 * Adds custom twig functions and filters for use by themes.
 */
class SiteExtensions extends AbstractExtension {

  /**
   * The theme manager.
   *
   * @var \Drupal\Core\Theme\ThemeManagerInterface
   */
  protected ThemeManagerInterface $themeManager;

  /**
   * Constructs \Drupal\site_wrapper\Plugin\TwigExtension.
   *
   * @param \Drupal\Core\Theme\ThemeManagerInterface $theme_manager
   *   The theme manager.
   */
  public function __construct(ThemeManagerInterface $theme_manager) {
    $this->themeManager = $theme_manager;
  }

  /**
   * Declare custom twig function.
   *
   * @return \Twig\TwigFunction[]
   *   TwigFunction array.
   */
  public function getFunctions(): array {
    return [
      new TwigFunction('dg_local_logo_fallback_lookup_favicon', [$this, 'getLogoFallBackToLocal']),
      new TwigFunction('dg_lookup_favicon', [$this, 'lookupFavicon']),
      new TwigFunction('dg_local_logo', [$this, 'getLocalLogo']),
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
  public function getLogoFallBackToLocal(string $uri): string {
    $host = parse_url($uri, PHP_URL_HOST);

    if (!$host || $host === 'digital.gov') {
      // Assume a local URL.
      return $this->getLocalLogo();
    }

    return self::buildFaviconSearch($uri);
  }

  /**
   * Get the Digital.gov logo.
   *
   * @return string
   *   The URL as a string.
   */
  public function getLocalLogo(): string {
    $path = '/' . $this->themeManager->getActiveTheme()->getPath() . '/static/digitalgov/img/digit-50.png';
    return Url::fromUserInput($path)->toString();
  }

  /**
   * Ask google for the favicon to use for a given URL.
   *
   * USAGE:
   *    {{ lookupFavicon(my_url) }}
   */
  public function lookupFavicon(string $uri): string {
    return self::buildFaviconSearch($uri);
  }

  /**
   * Builds the Google favicon search URI.
   */
  protected static function buildFaviconSearch(string $uri): string {
    $host = parse_url($uri, PHP_URL_HOST);
    return Url::fromUri('https://www.google.com/s2/favicons?domain=' . $host)->toString();
  }

}
