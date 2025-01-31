<?php

declare(strict_types=1);

namespace Drupal\convert_text;

use Drupal\Core\Url;
use Drupal\node\Entity\Node;
use Drupal\taxonomy\Entity\Term;
use League\CommonMark\CommonMarkConverter;

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

    switch ($field_type) {
      case 'plain_text':
        return html_entity_decode($source_text, ENT_QUOTES | ENT_SUBSTITUTE | ENT_HTML401, 'UTF-8');

      case 'html':
        $converter = new CommonMarkConverter();
        $content = $converter->convert($source_text)->getContent();
        return self::addLinkItMarkup($content);

      default:
        throw new \Exception("Invalid \$field_type of $field_type given");
    }
  }

  /**
   * Update local link tags with linkit data attributes.
   */
  protected static function addLinkItMarkup(string $source_text): string {
    $dom = new \DOMDocument();
    $dom->loadHTML($source_text);

    foreach ($dom->getElementsByTagName('a') as $link) {
      $href = $link->getAttribute('href');
      if (!$href) {
        continue;
      }

      $host = parse_url($href, PHP_URL_HOST) ?? '';

      if (in_array($host, ['', 'digital.gov', 'www.digital.gov'])) {
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
            // If someone links to the home page,
            // we don't need to modify the link.
            continue 2;

          default:
            // Do we want to log / warn here?
            continue 2;
        }

        $link->setAttribute('href', $sysPath);
        $link->setAttribute('data-entity-type', $entityType);
        $link->setAttribute('data-entity-uuid', $uuid);
        $link->setAttribute('data-entity-substitution', 'canonical');
      }
    }

    $body = $dom->getElementsByTagName('body')->item(0);
    $html = $dom->saveHTML($body);
    // No good way to keep white space AND omit the body tag automatically.
    return preg_replace(['/^<body>/', '/<\/body>$/'], '', $html);
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

}
