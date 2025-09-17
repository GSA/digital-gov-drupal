<?php

declare(strict_types=1);

namespace Drupal\digital_gov_migration\Plugin\migrate_plus\data_parser;

/**
 * Obtain JSON data for migration.
 *
 * Prepares the topics data so that we can import featured links
 * as paragraph entities with these fields:
 *
 *  - title: title
 *  - field_links: external links migrated by json_topics__featured_links_ext
 *
 * @DataParser(
 *   id = "json_topic_featured_links",
 *   title = @Translation("JSON Fetcher for Digital.gov Featured Featured Links for Topics")
 * )
 */
class JsonTopicFeaturedLinks extends JsonTamperer {

  /**
   * Alter topic feed to import featured links.
   */
  protected function alterFeed(&$feed): void {
    // Get the topics that have featured links and get them
    // into a format we can use to import as paragraphs.
    $items = array_filter($this->sourceData['items'], static function ($item) {
      return isset($item['field_featured_links'])
        && !empty($item['field_featured_links']);
    });

    $paragraphs = [];
    // Get each featured link as an item in the feed, even when
    // a topic has more than one.
    foreach ($items as $item) {
      $paragraph['uid'] = $item['uid'];
      $paragraph['field_featured_links_title'] = $item['field_featured_links_title'];
      $paragraph['field_featured_links'] = [];
      foreach ($item['field_featured_links'] as $link) {

        // UID with unchanged inputs.
        $link_para['link_uid'] = hash('sha256', $item['uid'] . '::' . $link['href']);
        $link_para['link_url'] = trim($link['href']);

        $link_para['link_title'] = trim($link['title']);

        $link_para['link_summary'] = trim($link['summary']) ?? '';

        // So we can use this with subprocess, this
        // must be an array of associative arrays.
        $paragraph['field_featured_links'][] = $link_para;
      }
      $paragraphs[] = $paragraph;
    }

    // Replace the original json with our paragraph imports.
    $feed['items'] = $paragraphs;
    $feed['count'] = count($paragraphs);
    $feed['content'] = 'topics__featured_links';
  }

}
