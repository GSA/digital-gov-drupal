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
        $source_text = static::prepareMarkdown($source_text);

        $converter = new CommonMarkConverter();
        $html = $converter->convert($source_text)->getContent();
        $html = LitEmoji::encodeUnicode($html);

        // Rewrite links to prod domain to current one for internal links.
        // Remove preview directories in link paths.
        // Remove preview directories in path to uswds images.
        $html = str_replace([
          ' href="https://digital.gov/',
          ' href="/preview/gsa/digitalgov.gov/nl-json-endpoints/',
          ' src="/preview/gsa/digitalgov.gov/nl-json-endpoints/img/',
          'xlink:href="/preview/gsa/digitalgov.gov/nl-json-endpoints/uswds/img/',
        ], [
          ' href="/',
          ' href="/',
          ' src="themes/custom/digital_gov/static/digitalgov/img/',
          'xlink:href="/themes/custom/digital_gov/static/uswds/img/',
        ], $html);

        if ($field_type === 'html_no_breaks') {
          $html = str_replace(['<p>', '</p>', '<br>', '<br />', '<br/>'], '', $html);
        }
        return $html;

      default:
        throw new \Exception("Invalid \$field_type of $field_type given");
    }
  }

  /**
   * Runs conversions that must happen after all content is migrated.
   */
  protected static function afterMigrate(string $source_text, string $field_type, string $baseURL = ''): string {
    switch ($field_type) {
      case 'plain_text':
        // Doesn't do anything yet, stubbed here in case we need it later.
        return $source_text;

      case 'html':
      case 'html_no_breaks':
        $source_text = self::fixShortCodes($source_text);
        $source_text = self::addLinkItMarkup($source_text, $baseURL);
        // Doesn't like when new lines are in the source text. Autop filter?
        $source_text = preg_replace('/\R/', "", $source_text);
        // Or p-tags around embedded content.
        $source_text = str_replace(
          ['<p><embedded-content', '</embedded-content></p>'],
          ['<embedded-content', '</embedded-content>'],
          $source_text
        );
        return $source_text;

      default:
        throw new \Exception("Invalid \$field_type of $field_type given");
    }
  }

  /**
   * Cleans up the markdown to prevent conversion bugs.
   */
  protected static function prepareMarkdown(string $source_text): string {
    // Targeted fixes to insure incoming HTML isn't mistaken for indented code.
    $source_text = preg_replace('/\/svg>(\R|\s)+([A-Za-z0-9]+)/', '/svg>$2', $source_text);
    // Remove any line breaks, whitespace before a closing heading.
    $source_text = preg_replace('/(\R+|\s+)(<\/h[0-9]+>)/i', '$2', $source_text);
    // Remove line breaks at the start of href.
    $source_text = preg_replace('/href="(\R|\s)+/', 'href="', $source_text);

    // Need to turn the link and ref shortcodes into regular markdown links.
    if (str_contains($source_text, '{{< ref') || str_contains($source_text, '{{< link')) {
      $source_text = preg_replace_callback(
        '/{{<\s+(ref|link)\s+\"?([^">]+).*}}/i',
        function ($match): string {
          $href = $match[2];
          if (str_starts_with($href, 'resources/')) {
            // It should be an absolute link.
            $href = '/' . $href;
          }

          if (str_starts_with($href, '/') && str_ends_with($href, '/_index.md')) {
            return str_replace('/_index.md', '/', $href);
          }

          if (!preg_match('/^https?\:\/\//', $href) && str_ends_with($href, '.md')) {
            return preg_replace('/\.md$/', '', $href);
          }

          // Either a full URL or something we can't readily fix.
          return $href;
        }, $source_text
      );
    }

    // When the source text has raw HTML, leading spaces are mistaken for
    // code blocks.
    $lines = array_map(function (string $line): string {
      return preg_replace('/^(\s+)</', "<", $line);
    }, explode("\n", $source_text));

    return implode("\n", $lines);
  }

  /**
   * Update local link tags with LinkIt data attributes.
   */
  protected static function addLinkItMarkup(string $source_text, string $baseURL = ''): string {
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

      // Prepend base URL to relative links.
      // Starts with a letter or number but no protocol.
      if ($baseURL
        && !str_starts_with($href, '/')
        && preg_match('/^(?![A-Za-z]+?:\/\/)([[:alnum:]]+)/', $href)
      ) {
        $href = $baseURL
          . (!str_ends_with($baseURL, '/') ? '/' : '')
          . $href;
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
   * Helper for calling the short code fixer service.
   */
  public static function fixShortCodes(string $source_text): string {
    return \Drupal::service('convert_text.shortcode_to_equiv')
      ->convert(md5($source_text), $source_text);
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
   * Runs post-migration cleanup for plain text fields.
   */
  public static function plainTextAfterMigrate(string $source_text): string {
    return self::afterMigrate($source_text, 'plain_text');
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
   * Runs post-migration cleanup for HTML fields.
   */
  public static function htmlTextAfterMigrate(string $source_text, string $baseURL = ''): string {
    return self::afterMigrate($source_text, 'html', $baseURL);
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

  /**
   * Runs post-migration cleanup for HTML-no-breaks fields.
   */
  public static function htmlNoBreaksAfterMigrate(string $source_text, string $baseURL = ''): string {
    return self::afterMigrate($source_text, 'html_no_breaks');
  }

}
