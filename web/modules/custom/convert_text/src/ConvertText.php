<?php

declare(strict_types=1);

namespace Drupal\convert_text;

use League\CommonMark\CommonMarkConverter;

/**
 * Provides methods to convert migrated text for fields.
 */
class ConvertText {

  /**
   * Converts text for the given $field_type.
   *
   * @var string $source_text
   *   The original source value.
   * @var string $field_type
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
        return $converter->convert($source_text)->getContent();

      default:
        throw new \Exception("Invalid \$field_type of $field_type given");

    }
  }

  /**
   * Gets text ready to be stored in plain text fields.
   *
   * @var string $source_text
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
   * @var string $source_text
   *   The original source value.
   *
   * @return string
   *   The converted text.
   */
  public static function htmlText(string $source_text): string {
    return self::convert($source_text, 'html');
  }

}
