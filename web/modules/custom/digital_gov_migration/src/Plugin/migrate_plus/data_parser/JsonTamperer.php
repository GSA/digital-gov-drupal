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
 *   id = "json_tamperer",
 * )
 */
abstract class JsonTamperer extends Json {

  /**
   * Allows a child class to modify the feed after retrieval.
   */
  protected function getSourceData(string $url, int|string $item_selector = '') {
    // Use cached source data if this is the first request or URL is same as the
    // last time we made the request.
    if ($this->currentUrl != $url || !$this->sourceData) {
      $response = $this->getDataFetcherPlugin()->getResponseContent($url);

      // Convert objects to associative arrays.
      $this->sourceData = json_decode($response, TRUE);

      // If json_decode() has returned NULL, it might be that the data isn't
      // valid utf8, <http://php.net/manual/en/function.json-decode.php#86997.>
      if (!$this->sourceData) {
        $utf8response = mb_convert_encoding($response, 'UTF-8');
        $this->sourceData = json_decode($utf8response, TRUE);
      }
      else {
        $this->alterFeed($this->sourceData);
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

  /**
   * Child classes must implement to alter feed.
   */
  abstract protected function alterFeed(&$feed): void;

}
