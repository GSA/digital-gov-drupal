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
 *   id = "json_topics",
 *   title = @Translation("JSON Fetcher and munger for Digital.gov for Topics")
 * )
 */
class JsonTopics extends JsonTamperer {

  /**
   * Prepare a feed so we can match related paragraphs.
   */
  protected function alterFeed(&$feed): void {
    foreach ($this->sourceData['items'] as &$item) {
      if (isset($item['field_featured_resources'])) {
        foreach ($item['field_featured_resources'] as &$resource) {
          $resource['parent_uid'] = $item['uid'];

          // Resource UID with unchanged inputs to match in migrations.
          $resource['resource_uid'] = hash('sha256', $item['uid'] . '::' . $resource['field_featured_resource_href']);
        }
      }
      else {
        $item['field_featured_resources'] = [];
      }

      if (isset($item['field_featured_links'])) {
        // We need this field to point to the uid set by the
        // JSON_topic_featured_links migration to match this node
        // with the paragraph for featured links.
        $item['field_featured_links'] = $item['uid'];
      }
      else {
        $item['field_featured_links'] = [];
      }

      if (empty($item['slug'])) {
        // Good-enough slugify.
        $item['slug'] = str_replace(' ', '-', strtolower($item['field_title']));
      }

      $item['resource_topic'] = $this->lookupResourceTopic($item['slug']);
    }
  }

  /**
   * Map slugs to resource topic term names.
   */
  private function lookupResourceTopic(string $slug): string {
    $map = [
      'communication' => 'Content & communication',
      'content-strategy' => 'Content & communication',
      'multilingual' => 'Content & communication',
      'multimedia' => 'Content & communication',
      'plain-language' => 'Content & communication',
      'podcast' => 'Content & communication',
      'social-media' => 'Content & communication',
      'trust' => 'Content & communication',

      'analytics' => 'Data & analysis',
      'crowdsourcing-and-citizen-science' => 'Data & analysis',
      'data-visualization' => 'Data & analysis',
      'information-collection' => 'Data & analysis',
      'open-data' => 'Data & analysis',
      'open-government' => 'Data & analysis',
      'research' => 'Data & analysis',
      'search' => 'Data & analysis',
      'search-engine-optimization' => 'Data & analysis',

      'accessibility' => 'Design',
      'customer-experience' => 'Design',
      'design' => 'Design',
      'digital-service-delivery' => 'Design',
      'human-centered-design' => 'Design',
      'information-architecture' => 'Design',
      'usability' => 'Design',
      'user-experience' => 'Design',

      'acquisition' => 'Operations',
      'budgeting-and-performance' => 'Operations',
      'contact-centers' => 'Operations',
      'intellectual-property' => 'Operations',
      'product-and-project-management' => 'Operations',
      'privacy' => 'Operations',
      'records-management' => 'Operations',
      'terms-of-service' => 'Operations',

      'best-practices' => 'Strategic development',
      'challenges-and-prize-competitions' => 'Strategic development',
      'governance' => 'Strategic development',
      'innovation' => 'Strategic development',
      'public-policy' => 'Strategic development',
      'professional-development' => 'Strategic development',

      'application-programming-interface' => 'Technology',
      'artificial-intelligence' => 'Technology',
      'cloud-and-infrastructure' => 'Technology',
      'domain-management' => 'Technology',
      'emerging-tech' => 'Technology',
      'mobile' => 'Technology',
      'open-source' => 'Technology',
      'robotic-process-automation' => 'Technology',
      'security' => 'Technology',
      'software-engineering' => 'Technology',
    ];

    return $map[$slug] ?? '';
  }

}
