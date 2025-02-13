<?php

declare(strict_types=1);

namespace Drupal\convert_text;

use Drupal\Component\Utility\Html;
use Drupal\Core\Url;
use Drupal\node\Entity\Node;
use Drupal\taxonomy\Entity\Term;
use League\CommonMark\CommonMarkConverter;
use LitEmoji\LitEmoji;

/**
 * Provides methods to convert migrated text for fields.
 */
class ConvertText {

  /**
   * Converts text for the given $field_type.
   *
   * @param string $source_text
   *   The original source value.
   * @param string $field_type
   *   Either plain or html.
   *
   * @return string
   *   The converted text.
   */
  protected static function convert(string $source_text, string $field_type): string {
    // Start by removing space before and after.
    $source_text = trim($source_text);
    // Remove extra spaces before new lines.
    $source_text = preg_replace('/\n\s+n/', "\n", $source_text);

    if (!strlen($source_text)) {
      return '';
    }

    switch ($field_type) {
      case 'plain_text':
        return html_entity_decode($source_text, ENT_QUOTES | ENT_SUBSTITUTE | ENT_HTML401, 'UTF-8');

      case 'html':
      case 'html_no_breaks':
        $converter = new CommonMarkConverter();
        $html = $converter->convert($source_text)->getContent();
        $html = LitEmoji::encodeUnicode($html);
        $html = self::addLinkItMarkup($html);
        if ($field_type === 'html_no_breaks') {
          $html = str_replace(['<p>', '</p>', '<br>', '<br />', '<br/>'], '', $html);
        }
        return $html;

      default:
        throw new \Exception("Invalid \$field_type of $field_type given");
    }
  }

  /**
   * Update local link tags with linkit data attributes.
   */
  protected static function addLinkItMarkup(string $source_text): string {

    // Consider these domains local.
    $base_domains = [\Drupal::request()->getHost(), 'digital.gov', 'www.digital.gov'];

    $dom = Html::load($source_text);

    foreach ($dom->getElementsByTagName('a') as $link) {
      $href = $link->getAttribute('href');
      if (!$href || str_starts_with($href, 'mailto:') || str_starts_with($href, '#')) {
        continue;
      }

      $anchor = '';
      if (preg_match('/\#(.*)$/', $href, $matches)) {
        $anchor = $matches[0];
      }

      // Add a trailing slash for links with just the domain w/o trailing slash.
      if (preg_match('/^https?:\/\/(' . implode('|', $base_domains) . ')$/', $href, $matches)) {
        $href = $matches[0] . '/';
      }
      // Now, strip the local domains from links that include them.
      $href = preg_replace(
        '/^https?:\/\/(' . implode('|', $base_domains) . ')/',
        '',
        $href, count: $replaced);
      if ($replaced > 0) {
        // HREF here includes any anchor.
        $link->setAttribute('href', $href);
      }

      $host = parse_url($href, PHP_URL_HOST) ?? '';
      if ($host === '') {
        $alias = parse_url($href, PHP_URL_PATH);

        $sysPath = \Drupal::service('path_alias.manager')->getPathByAlias($alias);

        // If a link already has all the linkit attributes, leave it be.
        if (
          $link->hasAttribute('data-entity-type')
          && $link->hasAttribute('data-entity-uuid')
          && $link->hasAttribute('data-entity-substitution')
        ) {
          continue;
        }

        $url = Url::fromUserInput($sysPath);

        if (!$url->isRouted()) {
          // What do we have here?
          $client = \Drupal::httpClient();

          $host = \Drupal::request()->getSchemeAndHttpHost();
          $response = $client->get($host . $sysPath, [
            // Don't throw exceptions on error codes.
            'http_errors' => FALSE,
            'allow_redirects' => [
              'max' => 10,
              'track_redirects' => TRUE,
            ],
          ]);

          if ($response->getStatusCode() > 400) {
            continue;
          }
          if ($response->getStatusCode() === 200) {
            if ($history = $response->getHeader('X-Guzzle-Redirect-History')) {
              $finalURI = $history[array_key_last($history)];
              $redirHost = parse_url($finalURI, PHP_URL_HOST);
              if (!str_ends_with($host, $redirHost)) {
                // We were redirected off site. Let's fix the link and move on.
                $link->setAttribute('href', $finalURI . $anchor);
                continue;
              }
              $redirPath = parse_url($finalURI, PHP_URL_PATH) ?? '/';
              $url = Url::fromUserInput($redirPath);
              if (!$url->isRouted()) {
                // Redirected to an unrouted path, not much we can do here.
                continue;
              }
              // Replace the alias in the href with the internal path.
              $sysPath = \Drupal::request()->getBasePath() . '/' . $url->getInternalPath();
            }
          }
          else {
            // Leave 40x links alone.
            continue;
          }
        }

        switch ($url->getRouteName()) {
          case 'entity.node.canonical':
            $params = $url->getRouteParameters();
            $node = Node::load($params['node']);
            if (!$node) {
              continue 2;
            }
            $entityType = 'node';
            $uuid = $node->uuid();
            break;

          case 'entity.taxonomy_term.canonical':
            $entityType = 'term';
            $params = $url->getRouteParameters();
            $term = Term::load($params['taxonomy_term']);
            if (!$term) {
              continue 2;
            }
            $uuid = $term->uuid();
            break;

          case '<front>':
            // Ensure the link to the homepage doesn't have a domain name.
            // Don't need to add any other attributes or anchor.
            $link->setAttribute('href', $href);
            continue 2;

          default:
            continue 2;
        }

        // Linkit saves the internal path and renders the alias.
        $link->setAttribute('href', $sysPath . $anchor);
        $link->setAttribute('data-entity-type', $entityType);
        $link->setAttribute('data-entity-uuid', $uuid);
        $link->setAttribute('data-entity-substitution', 'canonical');
      }
    }

    return Html::serialize($dom);
  }

  /**
   * Gets text ready to be stored in plain text fields.
   *
   * @param string $source_text
   *   The original source value.
   *
   * @return string
   *   The converted text.
   */
  public static function plainText(string $source_text): string {
    return self::convert($source_text, 'plain_text');
  }

  /**
   * Gets text ready to be stored in html text fields.
   *
   * @param string $source_text
   *   The original source value.
   *
   * @return string
   *   The converted text.
   */
  public static function htmlText(string $source_text): string {
    return self::convert($source_text, 'html');
  }

  /**
   * Gets text ready to be stored in html text fields without breaks.
   *
   * @var string $source_text
   *   The original source value.
   *
   * @return string
   *   The converted text.
   */
  public static function htmlNoBreaksText(string $source_text): string {
    return self::convert($source_text, 'html_no_breaks');
  }

}
