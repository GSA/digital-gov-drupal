<?php

declare(strict_types=1);

namespace Drupal\convert_text;

use Drupal\Component\Serialization\Json;
use Drupal\Component\Utility\Html;
use Drupal\Core\Entity\EntityTypeManagerInterface;
use Drupal\Core\Url;
use Drupal\migrate\MigrateLookupInterface;
use Drupal\path_alias\AliasManagerInterface;
use Psr\Log\LoggerInterface;

/**
 * Provides methods to convert Hugo shortcodes to their Drupal equivalent.
 */
class ShortcodeToEquiv {

  /**
   * The alias of the curren item being processed.
   *
   * @var string
   */
  protected string $aliasOfItem;

  /**
   * The alias manager service.
   *
   * @var \Drupal\path_alias\AliasManagerInterface
   */
  protected AliasManagerInterface $aliasManager;

  /**
   * The migration lookup service.
   *
   * @var \Drupal\migrate\MigrateLookupInterface
   */
  protected MigrateLookupInterface $migrateLookup;

  /**
   * The entity type manager service.
   *
   * @var \Drupal\Core\Entity\EntityTypeManagerInterface
   */
  protected EntityTypeManagerInterface $entityTypeManager;

  /**
   * A logger instance.
   *
   * @var \Psr\Log\LoggerInterface
   */
  protected LoggerInterface $logger;

  /**
   * Creates the ShortcodeToEquiv service.
   *
   * @param \Drupal\migrate\MigrateLookupInterface $migrate_lookup
   *   The migration lookup service.
   * @param \Drupal\path_alias\AliasManagerInterface $alias_manager
   *   The alias manager service.
   * @param \Drupal\Core\Entity\EntityTypeManagerInterface $entity_type_manager
   *   The entity type manager service.
   * @param \Psr\Log\LoggerInterface $logger
   *   A logger instance.
   */
  public function __construct(MigrateLookupInterface $migrate_lookup, AliasManagerInterface $alias_manager, EntityTypeManagerInterface $entity_type_manager, LoggerInterface $logger) {
    $this->migrateLookup = $migrate_lookup;
    $this->aliasManager = $alias_manager;
    $this->entityTypeManager = $entity_type_manager;
    $this->logger = $logger;
  }

  /**
   * Converts short codes in text to their Drupal equivalent.
   *
   * @var string $alias_of_item
   *   The alias of the item being processed.
   * @var string $source_text
   *   The original source value.
   * @var array $shortcodes
   *   If given, only the given shortcodes will be processed.
   *
   * @return string
   *   The converted text.
   */
  public function convert(string $alias_of_item, string $source_text, array $shortcodes = []): string {
    // Keep track of name for logging errors.
    $this->aliasOfItem = $alias_of_item;

    // Start by removing space before and after.
    $source_text = trim($source_text);
    // Running source text through markdown converter encodes the brackets in
    // the shortcode, we need to undo that (and hopefully just that).
    $source_text = str_replace(['{{&lt;', '&gt;}}'], ['{{<', '>}}'], $source_text);
    // Decode quotes inside any short code tags.
    $source_text = preg_replace_callback(
      '/\{\{<(.*)>\}\}/',
      function ($in) {
        return str_replace('&quot;', '"', $in[0]);
      },
      $source_text
    );

    // A structured array of the types of shortcodes that are allowed.
    // These two arrays didn't need to be separate, as the 'body' attribute
    // kept track of their differences, but it made confirming them easier.
    // Body just means 'does the short code allow a starting and ending tag
    // with text in between.
    $outer_tags_with_body = [
      'accordion' => ['body' => TRUE],
      'box' => ['body' => TRUE],
      'card-policy' => ['body' => TRUE],
      'card-prompt' => ['body' => TRUE],
      'checklist' => [
        'body' => FALSE,
        'children' => [
          // These are at the same level and order matters.
          'checkbox|checklist-sublist' => [
            'body' => FALSE,
            'children' => ['checkbox-sublist-item' => ['body' => TRUE]],
          ],
        ],
      ],
      'do-dont-table' => [
        'body' => FALSE,
        'children' => [
          'row' => [
            'body' => FALSE,
            'children' => [
              'do-row' => ['body' => TRUE],
              'dont-row' => ['body' => TRUE],
            ],
          ],
        ],
      ],
      'highlight' => ['body' => TRUE],
      'note' => ['body' => TRUE],
      'ring' => ['body' => TRUE],
    ];
    $outer_tags_without_body = [
      'asset-static' => ['body' => FALSE],
      'button' => ['body' => FALSE],
      'featured-resource' => ['body' => FALSE],
      'img' => ['body' => FALSE],
      'img-flexible' => ['body' => FALSE],
      'img-right' => ['body' => FALSE],
      'link' => ['body' => FALSE],
      'quote-block' => ['body' => FALSE],
      'ref' => ['body' => FALSE],
      'youtube' => ['body' => FALSE],
    ];
    if (empty($shortcodes)) {
      $shortcodes = array_merge($outer_tags_with_body, $outer_tags_without_body);
    }
    // A shortcode that has a body and closing tag.
    $body_regex = '/(\{\{<\s*%s(?![-\w])[^>]*>\}\})(.*?)(\{\{<\s*\/%s\s*>\}\})/sx';
    // A shortcode that has a body and closing tag AND order matters. For
    // example, checkbox and checklist-sublist must be in the order as given, if
    // they are processed individually they will stack and be out of order.
    $body_multi_regex = '/(\{\{<\s*(?:%s)(?![-\w])[^>]*>\}\})(.*?)(\{\{<\s*\/(?:%s)\s*>\}\})/sx';
    // A shortcode that has no body or closing tag.
    $without_body_regex = '/(\{\{<\s*%s(?![-\w])[^>]*>\}\})/sx';
    // A shortcode that has no body or closing tag and order matters. This is
    // not currently used or probably needed.
    $without_body_multi_regex = '/(\{\{<\s*(?:%s)(?![-\w])[^>]*>\}\})/sx';

    foreach ($shortcodes as $shortcode => $options) {
      $get_body = TRUE === $options['body'] || !empty($options['children']);
      if ($get_body) {
        if (str_contains($shortcode, '|')) {
          $pattern = sprintf($body_multi_regex, $shortcode, $shortcode);
        }
        else {
          $pattern = sprintf($body_regex, $shortcode, $shortcode);
        }
      }
      else {
        if (str_contains($shortcode, '|')) {
          $pattern = sprintf($without_body_multi_regex, $shortcode);
        }
        else {
          $pattern = sprintf($without_body_regex, $shortcode);
        }
      }
      preg_match_all($pattern, $source_text, $matches);
      if (!empty(array_filter($matches))) {
        foreach ($matches[1] as $key => $match) {
          $body = '';
          if ($get_body) {
            $body = trim($matches[2][$key] ?? '');
            if (
              (!empty($body) && $options['body'] === TRUE)
              || !empty($options['children'])
            ) {
              $body = $this->convert($alias_of_item, $body, $options['children'] ?? $shortcodes);
            }
          }
          // Get the current shortcode, unknown which if separated by | for
          // multiple.
          preg_match('/^\{\{<\s*([a-zA-Z0-9\-_]+)\b/', $match, $current_shortcode);
          $replace = $this->getDrupalEquiv($current_shortcode[1], $this->getAttributes($match), $body);
          $source_text = str_replace($matches[0][$key], $replace, $source_text);
        }
      }
    }

    return $source_text;
  }

  /**
   * Turns the attributes of a shortcode into an array.
   *
   * @param string $string
   *   The single or opening shortcode tag.
   *
   * @return array
   *   An array of attributes.
   */
  protected function getAttributes(string $string): array {
    $attributes = [];
    // Matches attributes surrounded by quotes, attributes with no key that are
    // quoted, and single word attributes that are not surrounded by quotes.
    $regex = '/([a-zA-Z0-9_-]+)\s*=\s*(?:"([^"]*)"|\'([^\']*)\'|([^\s>]+))|["\']([^"\']+)["\']/';

    preg_match_all($regex, $string, $matches, PREG_SET_ORDER);

    foreach ($matches as $match) {
      if (!empty($match[1])) {
        // Attributes can be empty. Also, if an attribute is not quoted,
        // the match is in capture group 4.
        $attributes[$match[1]] = $match[2] ?: $match[4] ?? '';
      }
      else {
        // Unnamed attribute only.
        $attributes[] = $match[5];
      }
    }

    return $attributes;
  }

  /**
   * The Drupal equivalent text for the given $shortcode.
   *
   * @param string $shortcode
   *   The name of the shortcode.
   * @param array $attributes
   *   The attributes of the shortcode as an array.
   * @param string $body
   *   The text between the start and end tag of shortcode.
   *
   * @return string
   *   The equivalent Drupal text.
   */
  protected function getDrupalEquiv(string $shortcode, array $attributes = [], string $body = ''): string {
    // Allows shortcodes to add to this variable to make more complex structures
    // between tags.
    static $building_array = [];
    switch ($shortcode) {
      case 'accordion':
        // Undo encoding of HTML tags in attributes to allow the shortcode
        // regex to work.
        $title = $this->decodeTagsInAttributes($attributes['title'] ?? '');

        $config = [
          'kicker' => ConvertText::htmlNoBreaksText($attributes['kicker'] ?? ''),
          'accordion_title' => $this->formattedFieldValue(
            $this->decodeTagsInAttributes($title),
            'single_inline_html'
          ),
          'icon' => $attributes['icon'] ?? '',
        ];
        $config['text'] = $this->formattedFieldValue($body);
        return $this->embeddedContent($config, 'ec_shortcodes_accordion');

      case 'box':
        return sprintf('<div class="box">%s</div>', ConvertText::htmlText($body));

      case 'card-policy':
        // Undo encoding of HTML tags in attributes.
        $title = $this->decodeTagsInAttributes($attributes['title'] ?? '');

        $config = [
          'kicker' => ConvertText::htmlNoBreaksText($attributes['kicker'] ?? ''),
          'card_title' => $this->formattedFieldValue(
            $this->decodeTagsInAttributes($title),
            'single_inline_html'
          ),
          'url' => $attributes['src'] ?? '',
        ];
        $config['text'] = $this->formattedFieldValue($body);
        return $this->embeddedContent($config, 'ec_shortcodes_card_policy');

      case 'card-prompt':
        if (empty($attributes['intro']) || empty($attributes['button-text']) || empty($attributes['button-url']) || empty($body)) {
          return $this->error($shortcode, 'intro, button-text, button-url, and some body text is required.');
        }

        // Undo encoding of HTML tags in attributes.
        $intro = $this->decodeTagsInAttributes($attributes['intro']);

        $config = [
          'intro' => $this->formattedFieldValue($intro),
          'text' => $attributes['button-text'],
          'url' => $attributes['button-url'],
        ];
        $config['prompt'] = $this->formattedFieldValue($body, 'html_embedded_content');
        return $this->embeddedContent($config, 'ec_shortcodes_card_prompt');

      case 'checklist':
        $classes = ['dg-checklist'];
        // The border attribute is only used to turn off the border. It's never
        // set to 'true' or something, only 'false'.
        if (isset($attributes['border'])) {
          $classes[] = 'dg-checklist--no-border';
        }
        $classes = implode(' ', $classes);
        return sprintf('<ul class="%s">%s</ul>', $classes, $body);

      case 'checkbox':
        return '<li>' . ConvertText::htmlNoBreaksText($body) . '</li>';

      // This only contains other short tags, nothing to do.
      case 'checklist-sublist':
        return "<ul>$body</ul>";

      case 'checkbox-sublist-item':
        $index_last = count($building_array) - 1;
        return '<li>' . ConvertText::htmlNoBreaksText($body) . '</li>';

      case 'do-dont-table':
        $config = [
          'caption' => !empty($attributes['caption']) ? ConvertText::htmlNoBreaksText($attributes['caption']) : '',
          'rows' => $building_array,
        ];
        $config['rows']['add_more'] = 'Add Row';
        // Now that this is built, zero out the children.
        $building_array = [];
        return $this->embeddedContent($config, 'ec_shortcodes_do_dont_table');

      case 'highlight':
        return sprintf('<span class="highlight-text">%s</span>', ConvertText::htmlNoBreaksText($body));

      case 'note':
        $variant = $attributes['variant'] ?? 'note';
        $config = [
          'heading' => ucfirst($variant),
          'type' => $variant,
        ];
        switch ($variant) {
          case 'join':
            $plugin_id = 'ec_shortcodes_note_join';
            break;

          case 'disclaimer':
            $plugin_id = 'ec_shortcodes_note_disclaimer';
            $body = '';
            break;

          default:
            $plugin_id = 'ec_shortcodes_note';
            break;

        }
        $config['text'] = $this->formattedFieldValue($body, 'html_embedded_content');
        return $this->embeddedContent($config, $plugin_id);

      case 'ring':
        $config = [
          'heading' => $attributes['title'],
        ];
        $config['text'] = $this->formattedFieldValue($body, 'html_embedded_content');
        return $this->embeddedContent($config, 'ec_shortcodes_ring');

      case 'youtube':
        if (empty($attributes['id'])) {
          return $this->error($shortcode, 'Unable to find YouTube video ID.');
        }
        $video_url = 'https://www.youtube.com/watch?v=' . $attributes['id'];
        $media_storage = $this->entityTypeManager->getStorage('media');
        $query = $media_storage->getQuery();
        $mids = $query->condition('bundle', 'video')
          ->condition('field_media_oembed_video', $video_url)
          ->accessCheck(FALSE)
          ->execute();
        if (!empty($mids)) {
          $mid = reset($mids);
          $video = $media_storage->load($mid);
        }
        else {
          $video = $media_storage->create([
            'name' => $attributes['title'] ?? $video_url,
            'field_media_oembed_video' => $video_url,
            'bundle' => 'video',
          ]);
          $video->save();
        }
        return $this->media($video->uuid());

      case 'asset-static':
        // The src for the migration is the filename without the extension.
        $src_uid = preg_replace('/\.(.*)$/', '', $attributes['file']);
        $uuid = $this->migrateLookup
          ->lookup(['json_files_to_media', 'json_s3_files_to_media'], [$src_uid]);
        if ($uuid) {
          $media = $this->entityTypeManager
            ->getStorage('media')
            ->load($uuid[0]['mid']);
          if ($media) {
            if (isset($attributes['button']) && strtolower($attributes['button']) === 'true') {
              return sprintf(
                '<a class="usa-button%s" href="%s" '
                . 'data-entity-type="media" data-entity-uuid="%s" data-entity-substitution="media"'
                . '>%s</a>',
                ($attributes['button-variant'] ?? FALSE) ? ' usa-button--outline' : '',
                "/media/" . $media->id(),
                $media->uuid(),
                $attributes['label'] ?? $attributes['href']
              );
            }
            else {
              if ($attributes['label'] ?? FALSE) {
                $media->setName($attributes['label']);
                $media->save();
              }
              return $this->media($media->uuid());
            }
          }
        }
        return $this->error($shortcode, 'Could not find file for: ' . $src_uid);

      case 'button':
        if (empty($attributes['href'])) {
          return $this->error($shortcode, 'Href is required.' . $attributes['text'] ?? '');
        }
        return sprintf(
          '<a href="%s" class="usa-button usa-button--outline">%s</a>',
          $attributes['href'],
          $attributes['text'] ?? $attributes['href']
        );

      case 'featured-resource':
        // $nid = $this->migrateLookup->lookup('resource_migration_id',
        // [$attributes['link']]);
        if (empty($attributes['link'])) {
          return '';
        }
        $link = $attributes['link'];
        if (!str_starts_with($link, 'http')) {
          // Ensure link starts with "/".
          if (!str_starts_with($link, '/')) {
            $link = '/' . $link;
          }
          // Ensure it does not end with "/".
          $link = rtrim($link, '/');
          // This should return a node/XYZ path, if not the path does not exist
          // yet.
          $system_path = $this->aliasManager->getPathByAlias($link);
          if ($system_path === $link) {
            return $this->error($shortcode, 'Could not find a node with path: ' . $attributes['link']);
          }
          $nid = str_replace('/node/', '', $system_path);
          $config = [
            'content_reference' => $nid,
            // @todo Kicker is being added in https://cm-jira.usa.gov/browse/DIGITAL-384.
            'kicker' => [
              'value' => trim(ConvertText::htmlNoBreaksText($attributes['kicker'] ?? '')),
              'format' => 'single_inline_html',
            ],
          ];
          return $this->embeddedContent($config, 'ec_shortcodes_featured_resource');
        }
        $config = [
          'kicker' => $attributes['kicker'] ?? '',
          'link' => $link,
          'summary' => $attributes['summary'] ?? '',
          'title' => $attributes['title'] ?? '',
        ];
        return $this->embeddedContent($config, 'ec_shortcodes_featured_resource_ext');

      case 'img':
      case 'img-flexible':
      case 'img-right':

        // As long as this runs after json_images_to_media has been imported,
        // we should be able to create the equivalent markup.
        $uuid = $this->migrateLookup
          ->lookup('json_images_to_media', [$attributes['src']]);
        if ($uuid) {
          $media = $this->entityTypeManager
            ->getStorage('media')
            ->load($uuid[0]['mid']);
          $orig_attributes = $attributes;
          $attributes = [];

          if ($shortcode === 'img-right' || ($orig_attributes['align'] ?? '') === 'right') {
            $attributes['data-align'] = 'right';
          }
          // Is there a Drupal equivalent for incoming inline=true?
          if (($orig_attributes['align'] ?? '') === 'center') {
            $attributes['data-align'] = 'center';
          }
          return $this->media($media->uuid(), $attributes);
        }
        return $this->error($shortcode, 'Could not find image for: .' . $attributes['src']);

      // Link is used in combination with markdown url syntax, so it is
      // important that shortcodes are replaced before markdown to HTMl is
      // applied.
      case 'link':
      case 'ref':
        $url = $attributes[0] ?? '';
        if (!strlen($url)) {
          return $this->error($shortcode, 'No URL can be found.');
        }
        // @todo Use migration lookup to find URL of content.
        // https://cm-jira.usa.gov/browse/DIGITAL-555
        // This is a reference to a piece of content in Hugo, use migration
        // lookup to find it.
        // @codingStandardsIgnoreStart
        if (str_ends_with($url, '.md') || ($shortcode === 'ref' && !str_starts_with($url, '/') && !str_starts_with($url, 'http'))) {
          $alias = preg_replace('/.md$/', '', $url);
          if ($url = Url::fromUserInput($alias)) {
            return  $url->toString();
          }
          return $alias;
        }
        // @codingStandardsIgnoreEnd
        // It's just a plain URL, return it.
        $parsed_url = parse_url($url);
        if (empty($parsed_url['host'])) {
          if (!str_starts_with($url, '/')) {
            // If this is a relative URL, make sure it starts with a /.
            $url = '/' . $url;
          }
        }
        return $url;

      case 'quote-block':
        if (empty($attributes['text'])) {
          return $this->error($shortcode, 'Text attribute is required.');
        }
        $dark = !empty($attributes['bg']) && $attributes['bg'] === 'dark';
        $config = [
          'cite' => $this->formattedFieldValue($attributes['cite'] ?? '', 'single_inline_html'),
          'text' => $this->formattedFieldValue($attributes['text'] ?? '', 'single_inline_html'),
          'dark' => $dark ? 1 : 0,
        ];
        return $this->embeddedContent($config, 'ec_shortcodes_card_quote');

      case 'row':
        // Nothing to do for a row, as the row is just made of other shortcodes.
        return $body;

      case 'do-row':
        $index = count($building_array);
        $building_array[] = ['do' => ConvertText::htmlNoBreaksText($body), '_weight' => $index, 'dont' => ''];
        return $body;

      case 'dont-row':
        $index_last = count($building_array) - 1;
        $building_array[$index_last]['dont'] = ConvertText::htmlNoBreaksText($body);
        return $body;

      default:
        throw new \Exception('Invalid shortcode ' . $shortcode . ' given.');
    }
  }

  /**
   * Create an embedded content tag that gets stored in a Drupal field.
   *
   * @param array $config
   *   The configuration that powers the data.
   * @param string $plugin_id
   *   The ID of the embedded content entity.
   *
   * @return string
   *   An embedded content tag.
   */
  protected function embeddedContent(array $config, string $plugin_id): string {
    $config = Html::escape(Json::encode(array_filter($config)));
    return sprintf('<embedded-content data-plugin-config="%s" data-plugin-id="%s" data-button-id="default">&nbsp;</embedded-content>', $config, $plugin_id);
  }

  /**
   * Decode UTF-8 encoded < > in a string.
   */
  protected function decodeTagsInAttributes(string $in): string {
    return str_replace(['\u003C', '\u003E'], ['<', '>'], $in);
  }

  /**
   * Create a media embed.
   *
   * @param string $uuid
   *   The media UUID.
   * @param array $attributes
   *   An additional array of attributes to give to the media tag.
   *
   * @return string
   *   A media embed string.
   */
  protected function media(string $uuid, array $attributes = []): string {
    $attributes['data-entity-type'] = 'media';
    $attributes['data-entity-uuid'] = $uuid;
    $pairs = [];
    foreach ($attributes as $key => $value) {
      $escaped_value = htmlspecialchars($value, ENT_QUOTES, 'UTF-8');
      $pairs[] = "{$key}=\"{$escaped_value}\"";
    }
    $attributes = implode(' ', $pairs);
    return sprintf('<drupal-media %s>&nbsp;</drupal-media>', $attributes);
  }

  /**
   * Create a formatted field value array.
   *
   * @param string $value
   *   The field value.
   * @param string $type
   *   The input format ID.
   *
   * @return array
   *   A formatted field array.
   */
  protected function formattedFieldValue(string $value, string $type = 'multiline_inline_html'): array {
    // Replace breaks with new lines so that the two portions get treated as
    // paragraph tags. Otherwise, the content entity embed module will complain
    // about br and p not being ended. This is fine because the WYSIWYG will
    // never make brs.
    $value = str_replace(['<br>', '<br />', '<br/>'], "\n", $value);
    return ['value' => ConvertText::htmlText($value), 'format' => $type];
  }

  /**
   * Log an error message.
   *
   * @param string $shortcode_id
   *   The shortcode type that couldn't be processed correctly.
   * @param string $message
   *   A helpful message of what went wrong.
   *
   * @return string
   *   A string to put in a field so one knows where to fix the issue.
   */
  protected function error(string $shortcode_id, string $message): string {
    // The alias of the item will tell us where to look for the message in the
    // return.
    $this->logger->warning(
      sprintf('ShortCodeToEquiv error with type: "%s". An alias of "%s". Message: "%s"',
        $shortcode_id,
        $this->aliasOfItem,
        $message
      )
    );
    return '<<< Fix Short Code Here. Type: ' . $shortcode_id . '. Message: ' . $message;
  }

}
