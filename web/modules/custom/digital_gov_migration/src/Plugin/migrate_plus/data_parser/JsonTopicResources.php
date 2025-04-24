<?php

declare(strict_types=1);

namespace Drupal\digital_gov_migration\Plugin\migrate_plus\data_parser;

use Drupal\migrate_plus\Plugin\migrate_plus\data_parser\Json;

/**
 * Obtain JSON data for migration.
 *
 * Prepares the topics data so that we can import featured resources
 * as paragraph entities with these fields:
 *
 *  - parent_uid: uid of the parent node
 *  - url: link to the resource, required
 *  - title: title, optional (internal ones in hugo don't have this)
 *  - summary: summary text, optional
 *
 * @DataParser(
 *   id = "json_topic_resources",
 *   title = @Translation("JSON Fetcher for Digital.gov Resources for Topics")
 * )
 */
class JsonTopicResources extends Json {

  /**
   * {@inheritdoc}
   */
  protected function getSourceData(string $url, int|string $item_selector = '') {
    // Use cached source data if this is the first request or URL is same as the
    // last time we made the request.
    if ($this->currentUrl != $url || !$this->sourceData) {
      $response = $this->getDataFetcherPlugin()->getResponseContent($url);

      // Convert objects to associative arrays.
      $this->sourceData = json_decode($response, TRUE);

      // Get the topics that have featured resources and get them
      // into a format we can use to import as paragraphs.
      $items = array_filter($this->sourceData['items'], static function ($item) {
        return isset($item['field_featured_resources'])
          && !empty($item['field_featured_resources']);
      });

      $paragraphs = [];

      foreach ($items as $item) {
        foreach ($item['field_featured_resources'] as $resource) {
          $paragraph = ['parent_uid' => $item['uid']];

          if (!$resource['field_featured_resource_href']) {
            trigger_error("Missing resource link", E_USER_WARNING);
            continue;
          }
          // UID with unchanged inputs.
          $paragraph['resource_uid'] = hash('sha256', $item['uid'] . '::' . $resource['field_featured_resource_href']);

          // HREF in the paragraph has to be a full URI with the local domain.
          $url = str_replace(
              'https://digital.gov/preview/gsa/digitalgov.gov/nl-json-endpoints/',
              'https://digital.gov/',
              $resource['field_featured_resource_href']
          );

          $paragraph['url'] = trim($url);

          if (isset($resource['field_featured_resource_title'])) {
            $paragraph['title'] = trim($resource['field_featured_resource_title']);
          }

          if (isset($resource['field_featured_resource_summary'])) {
            $paragraph['summary'] = $resource['field_featured_resource_summary'];
          }

          $paragraphs[] = $paragraph;
        }

      }

      // Replace the original json with our paragraph imports.
      $this->sourceData['items'] = $paragraphs;

      // If json_decode() has returned NULL, it might be that the data isn't
      // valid utf8, http://php.net/manual/en/function.json-decode.php#86997.
      if (!$this->sourceData) {
        $utf8response = mb_convert_encoding($response, 'UTF-8');
        $this->sourceData = json_decode($utf8response, TRUE);
      }
      $this->currentUrl = $url;
    }

    // Backwards-compatibility for depth selection.
    if (is_numeric($this->itemSelector)) {
      return $this->selectByDepth($this->sourceData, (int) $item_selector);
    }

    // If the item_selector is an empty string, return all.
    if ($item_selector === '') {
      return $this->sourceData;
    }

    // Otherwise, we're using xpath-like selectors.
    $selectors = explode('/', trim($item_selector, '/'));
    $return = $this->sourceData;
    foreach ($selectors as $selector) {
      // If the item_selector is missing, return an empty array.
      if (!isset($return[$selector])) {
        return [];
      }
      $return = $return[$selector];
    }
    return $return;
  }

}
