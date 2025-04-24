<?php

declare(strict_types=1);

namespace Drupal\digital_gov_migration\Plugin\migrate_plus\data_parser;

/**
 * Obtain JSON data for migration.
 *
 * Prepares the sources data so that we can download logo files to media.
 *
 * @DataParser(
 *   id = "json_sources",
 *   title = @Translation("JSON Fetcher and munger for Digital.gov for Topics")
 * )
 */
class JsonSources extends JsonTamperer {

  /**
   * Prepare a feed so we can match related paragraphs.
   */
  protected function alterFeed(&$feed): void {
    foreach ($this->sourceData['items'] as &$item) {
      // Doing this here since YAMLing doesn't work.
      if (
        isset($item['field_logo'])
        && str_starts_with($item['field_logo'], '/static/')
      ) {
        // Replacing with "" because we're prepending the base URL
        // with a trailing slash.
        $item['field_logo'] = preg_replace('/^\/static\//', '', $item['field_logo']);
        $item['logo_basename'] = basename($item['field_logo']);
      }
      else {
        $item['field_logo'] = [];
      }
    }
  }

}
