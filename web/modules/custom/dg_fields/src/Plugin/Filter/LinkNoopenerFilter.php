<?php

namespace Drupal\dg_fields\Plugin\Filter;

use Drupal\Component\Utility\Html;
use Drupal\Core\StringTranslation\TranslatableMarkup;
use Drupal\filter\Attribute\Filter;
use Drupal\filter\FilterProcessResult;
use Drupal\filter\Plugin\FilterBase;
use Drupal\filter\Plugin\FilterInterface;

/**
 * Adds rel="noopener noreferrer" to links that open in a new tab.
 *
 * Without it, the page opened in the new tab can reach this one through
 * window.opener and send it somewhere else (reverse tabnabbing). Browsers
 * only add noopener on their own for target="_blank", not for named targets.
 */
#[Filter(
  id: 'dg_fields_link_noopener',
  title: new TranslatableMarkup('Add rel="noopener noreferrer" to links that open in a new tab'),
  type: FilterInterface::TYPE_TRANSFORM_IRREVERSIBLE,
  weight: 20,
)]
class LinkNoopenerFilter extends FilterBase {

  /**
   * Targets that navigate a tab that already exists.
   */
  const EXISTING_TAB_TARGETS = ['', '_self', '_parent', '_top'];

  /**
   * {@inheritdoc}
   */
  public function process($text, $langcode): FilterProcessResult {
    if (!str_contains((string) $text, 'target')) {
      return new FilterProcessResult($text);
    }

    $document = Html::load($text);
    $changed = FALSE;
    foreach ((new \DOMXPath($document))->query('//a[@target] | //area[@target]') as $link) {
      if (!$link instanceof \DOMElement || !self::opensNewTab($link->getAttribute('target'))) {
        continue;
      }
      $rel = self::addNoopener($link->getAttribute('rel'));
      if ($rel !== $link->getAttribute('rel')) {
        $link->setAttribute('rel', $rel);
        $changed = TRUE;
      }
    }

    return new FilterProcessResult($changed ? Html::serialize($document) : $text);
  }

  /**
   * Whether a link with this target attribute opens a new tab.
   */
  public static function opensNewTab(string $target): bool {
    return !in_array(strtolower(trim($target)), self::EXISTING_TAB_TARGETS, TRUE);
  }

  /**
   * Adds noopener and noreferrer to a rel attribute value, keeping the rest.
   */
  public static function addNoopener(string $rel): string {
    $tokens = preg_split('/\s+/', trim($rel), -1, PREG_SPLIT_NO_EMPTY);
    foreach (['noopener', 'noreferrer'] as $token) {
      if (!in_array($token, array_map('strtolower', $tokens), TRUE)) {
        $tokens[] = $token;
      }
    }
    return implode(' ', $tokens);
  }

}
