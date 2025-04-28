<?php

declare(strict_types=1);

namespace Drupal\digital_gov_migration\Plugin\migrate_plus\data_parser;

/**
 * Obtain JSON data for migration.
 *
 * Prepares the sources data so that we can download logo files to media.
 *
 * @DataParser(
 *   id = "json_authors",
 *   title = @Translation("JSON Fetcher and munger for Digital.gov for Authors")
 * )
 */
class JsonAuthors extends JsonTamperer {

  /**
   * Prepare a feed so we can match related paragraphs.
   */
  protected function alterFeed(&$feed): void {
    foreach ($this->sourceData['items'] as &$item) {
      if (
        $item['uid'] === 'abigail-abby-bowman'
        && !isset($item['field_display_name'])
      ) {
        $item['field_display_name'] = $item['field_first_name'] . ' ' . $item["field_last_name"];
      }

      if (
        $item["uid"] === 'Authors'
        && !isset($item['field_display_name'])
      ) {
        $item['field_display_name'] = 'Authors';
      }
    }
  }

}
