<?php

declare(strict_types=1);

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
class JsonGuides extends JsonTamperer {

  /**
   * Prepare guide item fields for import.
   */
  protected function alterFeed(&$feed): void {
    foreach ($this->sourceData['items'] as &$item) {
      if ($item['filepath'] === "/content/guides/_index.md"
        || $item['filepath'] === "/content/guides/hcd/_index.md"
      ) {
        // Don't import these index pages, they're different node type.
        $item = NULL;
        continue;
      }

      if (
        isset($item['field_primary_image'])
          && $item['field_primary_image'] === 'hcd-guide-intro'
          && $item['url'] === '/guides/hcd/introduction/'
      ) {
        // The feed for guides has the wrong image slug.
        $item['field_primary_image'] = 'hcd-intro';
      }

      if (isset($item['field_glossary'])) {
        // Generate the machine name for the term ID.
        $name = str_replace(['-', '.json'], ['_', ''], $item['field_glossary']);
        $item['field_glossary_name'] = $name;
      }
    }

    $this->sourceData['items'] = array_filter($this->sourceData['items']);
    $this->sourceData['count'] = count($this->sourceData['items']);
  }

}
