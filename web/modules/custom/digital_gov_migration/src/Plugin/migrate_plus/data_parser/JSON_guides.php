<?php

declare(strict_types = 1);

namespace Drupal\digital_gov_migration\Plugin\migrate_plus\data_parser;

/**
 * Obtain JSON data for migration.
 *
 * Prepares the topics data so that we can import featured resources and links
 * as paragraph entities.
 *
 * @DataParser(
 *   id = "json_guides",
 *   title = @Translation("JSON Fetcher and munger for Digital.gov for Guides")
 * )
 */
class JSON_guides extends JSON_tamperer {
  protected function alterFeed(&$feed): void
  {
    foreach ($this->sourceData['items'] as &$item) {
      if (isset($item['field_glossary'])) {
        // try to generate the machine name the term ID
        $name = str_replace(['-', '.json'], ['_', ''], $item['field_glossary']);
        $item['field_glossary_name'] = $name;
      }
    }
  }
}
