<?php

declare(strict_types=1);

namespace Drupal\digital_gov_migration\Plugin\migrate_plus\data_parser;

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
 *   id = "json_topic_featured_links_ext",
 *   title = @Translation("JSON Fetcher for Digital.gov Featured External Links Resources for Topics")
 * )
 */
class JsonTopicFeaturedExtLinks extends JsonTamperer {

  /**
   * Alter the main topic feed to import featured links.
   */
  protected function alterFeed(&$feed): void {
    // Get the topics that have featured resources and get them
    // into a format we can use to import as paragraphs.
    $items = array_filter($this->sourceData['items'], static function ($item) {
      return isset($item['field_featured_links'])
        && !empty($item['field_featured_links']);
    });

    $paragraphs = [];
    // Get each featured link as an item in the feed, even when
    // a topic has more than one.
    foreach ($items as $item) {
      foreach ($item['field_featured_links'] as $link) {
        $paragraph = ['parent_uid' => $item['uid']];

        // UID with unchanged inputs.
        $paragraph['uid'] = hash('sha256', $item['uid'] . '::' . $link['href']);
        $paragraph['link_url'] = trim($link['href']);

        $paragraph['link_title'] = trim($link['title']);

        $paragraph['link_summary'] = trim($link['summary']) ?? '';

        $paragraphs[] = $paragraph;
      }
    }

    // Replace the original json with our paragraph imports.
    $feed['items'] = $paragraphs;
    $feed['count'] = count($paragraphs);
    $feed['content'] = 'topics__featured_links';
  }

}
