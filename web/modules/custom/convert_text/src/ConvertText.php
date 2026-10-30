<?php

declare(strict_types=1);

namespace Drupal\convert_text;

use League\CommonMark\Environment\Environment;
use League\CommonMark\Extension\Autolink\AutolinkExtension;
use League\CommonMark\Extension\CommonMark\CommonMarkCoreExtension;
use League\CommonMark\Extension\Table\TableExtension;
use League\CommonMark\MarkdownConverter;
use LitEmoji\LitEmoji;

/**
 * Provides methods to convert migrated text for fields.
 */
class ConvertText {

  /**
   * Converts text for the given $field_type.
   *
   * @param string $source_text
   *   The original source value.
   * @param string $field_type
   *   Either plain or html.
   *
   * @return string
   *   The converted text.
   */
  protected static function convert(string $source_text, string $field_type): string {
    // Start by removing space before and after.
    $source_text = trim($source_text);
    // Remove extra spaces before new lines.
    $source_text = preg_replace('/\n\s+n/', "\n", $source_text);

    if (!strlen($source_text)) {
      return '';
    }

    switch ($field_type) {
      case 'plain_text':
        return html_entity_decode($source_text, ENT_QUOTES | ENT_SUBSTITUTE | ENT_HTML401, 'UTF-8');

      case 'html':
      case 'html_no_breaks':
        $source_text = static::prepareMarkdown($source_text);
        // Configure markdown converter to support commonmark and table support.
        $environment = new Environment();
        $environment->addExtension(new CommonMarkCoreExtension());
        $environment->addExtension(new TableExtension());
        $environment->addExtension(new AutolinkExtension());

        // Leaving this commented out because enabling this extension
        // breaks all the regexes used during migration.
        // $environment->addExtension(new SmartPunctExtension());
        $converter = new MarkdownConverter($environment);
        $html = $converter->convert($source_text)->getContent();

        // Targeted fixes to allow HTML in title attributes for some shortcode
        // opening tags. If the attribute contains a ">", the regexes
        // for finding shortcode won't work.
        $allowHtmlTags = [
          'card-prompt' => ['intro'],
          'card-policy' => ['title'],
          'accordion' => ['title'],
        ];
        foreach ($allowHtmlTags as $code => $attributes) {
          foreach ($attributes as $attribute) {
            $html = static::encodeShortcodeAttr($html, $code, $attribute);
          }
        }

        $html = LitEmoji::encodeUnicode($html);

        // Rewrite links to prod domain to current one for internal links.
        // Remove preview directories in link paths.
        // Remove preview directories in path to uswds images.
        $html = str_replace([
          ' href="https://digital.gov/',
          ' href="/preview/gsa/digitalgov.gov/nl-json-endpoints/',
          ' src="/preview/gsa/digitalgov.gov/nl-json-endpoints/img/',
          'xlink:href="/preview/gsa/digitalgov.gov/nl-json-endpoints/uswds/img/',
        ], [
          ' href="/',
          ' href="/',
          ' src="themes/custom/digital_gov/static/digitalgov/img/',
          'xlink:href="/themes/custom/digital_gov/static/uswds/img/',
        ], $html);

        if ($field_type === 'html_no_breaks') {
          $html = str_replace(['<p>', '</p>', '<br>', '<br />', '<br/>'], '', $html);
        }
        return $html;

      default:
        throw new \Exception("Invalid \$field_type of $field_type given");
    }
  }

  /**
   * Encode < and > characters in a short code attribute.
   *
   * If they're present in an attribute, the regex for finding short codes
   * does not work.
   */
  private static function encodeShortcodeAttr(string $source, string $code, string $attr): string {
    $source = preg_replace_callback(
      '/\{\{&lt;\s*(' . preg_quote($code, '/') . ')\s*(.*)&gt;\}\}/iU',
      function ($matches) use ($attr): string {
        if (empty($matches[2])) {
          // No attributes, nothing to do.
          return $matches[0];
        }
        $attrs = $matches[2];
        // Fix requested attribute.
        $attrs = preg_replace_callback(
          '/' . preg_quote($attr, '/') . '=&quot;(.+)&quot;\s+/iU',
          function ($values) use ($attr): string {
            // Encoding angle brackets as UTF-8 entities used ultimately by the
            // embedded content module to save the config for it.
            return $attr . '=&quot;'
              . str_replace(['<', '>'], ['\u003C', '\u003E'], $values[1])
              . '&quot; ';
          },
          $attrs
        );
        return '{{&lt; ' . $matches[1] . ' ' . $attrs . ' &gt;}}';
      },
      $source
    );

    return $source;
  }

  /**
   * Cleans up the markdown to prevent conversion bugs.
   */
  protected static function prepareMarkdown(string $source_text): string {
    // Targeted fixes to insure incoming HTML isn't mistaken for indented code.
    $source_text = preg_replace('/\/svg>(\R|\s)+([A-Za-z0-9]+)/', '/svg>$2', $source_text);
    // Remove any line breaks, whitespace before a closing heading.
    $source_text = preg_replace('/(\R+|\s+)(<\/h[0-9]+>)/i', '$2', $source_text);
    // Remove line breaks at the start of href.
    $source_text = preg_replace('/href="(\R|\s)+/', 'href="', $source_text);

    // Need to turn the link and ref shortcodes into regular markdown links.
    if (str_contains($source_text, '{{< ref') || str_contains($source_text, '{{< link')) {
      $source_text = preg_replace_callback(
        '/{{<\s+(ref|link)\s+\"?([^">]+.*) >}}/iU',
        function ($match): string {
          $href = rtrim($match[2], '"');
          if (str_starts_with($href, 'resources/')) {
            // It should be an absolute link.
            $href = '/' . $href;
          }

          if (str_starts_with($href, '/') && str_ends_with($href, '/_index.md')) {
            return str_replace('/_index.md', '/', $href);
          }

          if (!preg_match('/^https?\:\/\//', $href) && str_ends_with($href, '.md')) {
            return preg_replace('/\.md$/', '', $href);
          }

          // Either a full URL or something we can't readily fix.
          return $href;
        }, $source_text
      );
    }

    if (str_contains($source_text, '](https://s3.amazonaws.com/digitalgov/static/')) {
      // Turn direct links to S3 files to asset shortcodes we can link to media
      // links during the post-migration cleanup.
      $source_text = preg_replace_callback(
        '/\[([^]]+)\]\(https?\:\/\/s3\.amazonaws\.com\/digitalgov\/static\/([^)]+)\)/',
        function ($match): string {
          return sprintf('{{< asset-static file="%s" label="%s" >}}',
            $match[2], $match[1]
          );
        },
        $source_text
      );
    }

    // When the source text has raw HTML, leading spaces are mistaken for
    // code blocks.
    $lines = array_map(function (string $line): string {
      return preg_replace('/^(\s+)</', "<", $line);
    }, explode("\n", $source_text));

    return implode("\n", $lines);
  }

  /**
   * Gets text ready to be stored in plain text fields.
   *
   * @param string $source_text
   *   The original source value.
   *
   * @return string
   *   The converted text.
   */
  public static function plainText(string $source_text): string {
    return self::convert($source_text, 'plain_text');
  }

  /**
   * Gets text ready to be stored in html text fields.
   *
   * @param string $source_text
   *   The original source value.
   *
   * @return string
   *   The converted text.
   */
  public static function htmlText(string $source_text): string {
    return self::convert($source_text, 'html');
  }

  /**
   * Gets text ready to be stored in html text fields without breaks.
   *
   * @var string $source_text
   *   The original source value.
   *
   * @return string
   *   The converted text.
   */
  public static function htmlNoBreaksText(string $source_text): string {
    return self::convert($source_text, 'html_no_breaks');
  }

}
