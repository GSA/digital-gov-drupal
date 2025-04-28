<?php

namespace Drupal\digital_gov_migration\Commands;

use Drupal\Component\Serialization\Json;
use Drupal\convert_text\ShortcodeToEquiv;
use Drupal\Core\Entity\EntityFieldManagerInterface;
use Drupal\Core\Entity\EntityTypeManagerInterface;
use Drupal\Core\Http\ClientFactory;
use Drupal\node\NodeInterface;
use Drupal\paragraphs\Entity\ParagraphsType;
use Drush\Commands\DrushCommands;
use Symfony\Component\Console\Helper\ProgressBar;
use Drupal\convert_text\ConvertText;

/**
 * A Drush commandfile for tasks to run after all content is migrated.
 */
final class PostImportCommands extends DrushCommands {

  // Formatted text fields we might want to process.
  const HTML_FIELDS = [
    'text_with_summary',
    'text_long',
  ];

  const HTML_FORMATS = [
    'html',
    'html_embedded_content',
    'multiline_html_limited',
    'multiline_inline_html',
    'single_inline_html',
  ];

  public function __construct(
    private EntityTypeManagerInterface $entityTypeManager,
    private EntityFieldManagerInterface $fieldManager,
    private ShortcodeToEquiv $shorcodeToEquiv,
    private ClientFactory $httpClientFactory,
  ) {
    parent::__construct();
  }

  /**
   * Update HTML with references to internal content.
   *
   * @command digitalgov:update-nodes
   * @option types Optional comma-separated list of types to update
   */
  public function updateNodes(array $options = ['types' => []]): void {
    $this->output()->writeln('<info>Starting HTML field update for nodes.</info>');

    if ($options['types'][0] ?? FALSE) {
      $options['types'] = explode(',', trim($options['types'][0]));
    }

    $bundles = $this->getContentTypesAndFields($options['types'] ?? []);
    foreach ($bundles as $bundle => $fields) {
      $this->output()->writeln("\n<info>Updating " . $bundle . ' nodes.</info>');
      $this->updateBundle($bundle, $fields);
    }

    $this->output()->writeln('');
    $this->output()->writeln('<info>Done.</info>');
  }

  /**
   * Update HTML with references to internal content.
   *
   * @command digitalgov:update-node
   * @argument nid Node ID
   */
  public function updateSingleNode(int $nid): void {
    $nodes = $this->entityTypeManager
      ->getStorage('node')
      ->loadByProperties(['nid' => $nid]);

    $node = array_pop($nodes);

    $this->output()->writeln('<info>Starting HTML field update for node: '
      . $node->getTitle() . ' (' . $node->getType() . ').</info>');

    $bundles = $this->getContentTypesAndFields([$node->getType()]);

    $this->updateNode($node, $bundles[$node->getType()]);
  }

  /**
   * Update all nodes of a single type.
   */
  private function updateBundle(string $bundle, array $fields): void {
    $nodes = $this->entityTypeManager
      ->getStorage('node')
      ->loadByProperties(['type' => $bundle]);

    $max = count($nodes);

    $progressBar = new ProgressBar($this->output, $max);
    $progressBar->start();

    foreach ($nodes as $node) {
      $this->updateNode($node, $fields);

      $progressBar->advance();
    }

    $progressBar->finish();
  }

  /**
   * Handle updating all the fields for a node.
   */
  private function updateNode(NodeInterface $node, array $fields): void {
    $changed = FALSE;
    foreach ($fields as $fieldName => $fieldConfig) {
      foreach ($node->get($fieldName) as &$item) {
        // Need the actual format used by this field.
        $original = $item->get('value')->getValue();
        try {
          // Logged by shortcode converter.
          $alias = 'node::' . $node->id() . '::' . $fieldName;
          // Need the actual format used by this field.
          switch ($item->get('format')->getValue()) {
            case 'single_inline_html':
              // Fixes LinkIt.
              $updated = ConvertText::htmlNoBreaksAfterMigrate($original, $node->toUrl()->toString());
              $updated = $this->shorcodeToEquiv->convert($alias, $updated);
              $item->set('value', $updated);
              $changed = $changed || ($updated !== $original);

              break;

            case 'html_embedded_content':
            case 'multiline_html_limited':
            case 'multiline_inline_html':
            case 'html':
              // Adds drupal attributes and converts short codes.
              $updated = ConvertText::htmlTextAfterMigrate($original, $node->toUrl()->toString());
              $item->set('value', $updated);
              $changed = $changed || ($updated !== $original);
              break;
          }
        }
        catch (\Exception $exception) {
          $this->output()->writeln('');
          $this->output()->writeln('<error>Failed to update node '
            . $node->id() . ', ' . $node->toUrl()->toString()
            . '</error>');
          trigger_error($exception->getMessage(), E_USER_WARNING);
          $changed = FALSE;
        }
      }
    }

    if ($changed) {
      // Don't change modified dates.
      $node->setSyncing(TRUE);
      $node->save();
    }
  }

  /**
   * Determine what node types and fields to update.
   */
  private function getContentTypesAndFields(array $bundles = []): array {
    $types = [];
    $contentTypes = $this->entityTypeManager->getStorage('node_type')->loadMultiple();
    foreach ($contentTypes as $contentType) {
      if ($bundles && !in_array($contentType->id(), $bundles)) {
        continue;
      }

      $fields = $this->fieldManager->getFieldDefinitions('node', $contentType->id());
      // Keep HTML fields that we need to update.
      $fields = array_filter($fields, [$this, 'filterField']);

      if ($fields) {
        $types[$contentType->id()] = $fields;
      }
    }

    if (empty($types)) {
      throw new \InvalidArgumentException('No fields/content types found to process.');
    }
    return $types;
  }

  /**
   * Determines what paragraph types and fields to update.
   */
  private function getParagraphTypesAndFields(array $bundles = []): array {
    $paragraphTypes = ParagraphsType::loadMultiple();
    $types = [];

    foreach ($paragraphTypes as $paragraphType) {
      if ($bundles && !in_array($paragraphType->id(), $bundles)) {
        continue;
      }

      $fields = $this->fieldManager->getFieldDefinitions('paragraph', $paragraphType->id());
      // Keep HTML fields that we need to update.
      if ($fields = array_filter($fields, [$this, 'filterField'])) {
        $types[$paragraphType->id()] = $fields;
      }
    }

    if (empty($types)) {
      throw new \InvalidArgumentException('No content types found.');
    }
    return $types;
  }

  /**
   * Checks if a field should be processed.
   */
  private function filterField($field): bool {
    if (!in_array($field->getType(), self::HTML_FIELDS)) {
      return FALSE;
    }

    $allowed = $field->getSetting('allowed_formats');
    if (!array_intersect($allowed, self::HTML_FORMATS)) {
      return FALSE;
    }

    return TRUE;
  }

  /**
   * Update HTML with references to internal content.
   *
   * @command digitalgov:update-paragraphs
   * @option types Optional comma-separated list of bundles to update
   */
  public function updateParagraphs(array $options = ['types' => []]): void {
    $this->output()->writeln('<info>Starting HTML field update for paragraphs.</info>');

    if ($options['types'][0] ?? FALSE) {
      $options['types'] = explode(',', trim($options['types'][0]));
    }

    $types = $this->getParagraphTypesAndFields($options['types']);

    foreach ($types as $paragraph => $fields) {
      $this->output()->writeln("\n<info>Updating {$paragraph} paragraphs.</info>");
      $this->updateParagraphType($paragraph, $fields);
    }

    $this->output()->writeln('');
    $this->output()->writeln('<info>Done.</info>');
  }

  /**
   * Updates all instances of a paragraph type.
   */
  private function updateParagraphType(string $type, array $fields): void {
    $storage = $this->entityTypeManager->getStorage('paragraph');
    $paragraphs = $storage->loadByProperties(['type' => $type]);

    $max = count($paragraphs);

    $progressBar = new ProgressBar($this->output, $max);
    $progressBar->start();

    foreach ($paragraphs as $para) {
      $changed = FALSE;
      foreach ($fields as $fieldName => $fieldConfig) {
        foreach ($para->get($fieldName) as &$item) {
          // Need the actual format used by this field.
          $original = $item->get('value')->getValue();
          try {
            switch ($item->get('format')->getValue()) {
              case 'single_inline_html':
                // Fixes LinkIt.
                $updated = ConvertText::htmlNoBreaksAfterMigrate($original);
                $item->set('value', $updated);
                $changed = $changed || ($updated !== $original);
                break;

              case 'html_embedded_content':
              case 'multiline_html_limited':
              case 'multiline_inline_html':
              case 'html':
                // Fixes Linkit.
                $updated = ConvertText::htmlNoBreaksAfterMigrate($original);
                $item->set('value', $updated);
                $changed = $changed || ($updated !== $original);
                break;
            }
          }
          catch (\Exception $exception) {
            $this->output()->writeln('');
            $this->output()->writeln('<error>Failed to update Paragraph ' . $para->id() . '</error>');
            trigger_error($exception->getMessage(), E_USER_WARNING);
            $changed = FALSE;
          }
        }
      }

      if ($changed) {
        // Don't change modified dates.
        $para->setSyncing(TRUE);
        $para->save();
      }

      $progressBar->advance();
    }

    $progressBar->finish();
  }

  /**
   * Builds a json feed of files in markdown that are direct links to s3 bucket.
   *
   * @command digitalgov:s3feed
   */
  public function buildS3DirectLinksFeed(): void {
    $client = $this->httpClientFactory->fromOptions([
      'base_uri' => 'https://federalist-466b7d92-5da1-4208-974f-d61fd4348571.sites.pages.cloud.gov/',
    ]);

    $feed_tpl = 'preview/gsa/digitalgov.gov/nl-json-endpoints/%s/index.json';

    // Based on greping through the Hugo source for direct links to S3 static.
    $sources = array_map(
      fn($type) => sprintf($feed_tpl, $type),
      ['news', 'resources', 'events', 'guides']
    );

    $discovered = [];
    foreach ($sources as $source) {
      $response = $client->get($source);
      $json = Json::decode($response->getBody());

      foreach ($json['items'] as $item) {
        // No body: /resources/guide-paperwork-reduction-act/
        // Avoid regexes if we can.
        if (
          !isset($item['field_body'])
          || !str_contains($item['field_body'], '](https://s3.amazonaws.com/digitalgov/static/')
        ) {
          continue;
        }

        $s3Links = $this->getS3Links($item['field_body']);
        foreach ($s3Links as $link) {

          $filename = preg_replace('/\..+$/', '', $link['file']);
          preg_match('/\.(.+)$/', $link['file'], $ext);
          $file = [
            'date' => date('Y-m-d H:i:s O'),
            'source' => 'https://s3.amazonaws.com/digitalgov/static/' . $link['file'],
            'uid' => $filename,
            'type' => $ext[1],
          ];
          $discovered[] = $file;
        }
      }
    }

    // Send the json to stdout to save for import.
    echo Json::encode($discovered);
  }

  /**
   * Extract links to s3 amazonaws bucket.
   */
  private function getS3Links(string $text): array {
    preg_match_all(
      '/\[([^]]+)\]\(https?\:\/\/s3\.amazonaws\.com\/digitalgov\/static\/([^)]+)\)/',
      $text,
      $matches
    );

    $links = [];
    foreach ($matches[0] as $idx => $match) {
      $links[] = [
        'label' => $matches[1][$idx],
        'file' => $matches[2][$idx],
      ];
    }

    return $links;
  }

}
