<?php

namespace Drupal\ec_uswds\Plugin\Filter;

use Drupal\Component\Utility\Html;
use Drupal\Core\StringTranslation\TranslatableMarkup;
use Drupal\filter\Attribute\Filter;
use Drupal\filter\FilterProcessResult;
use Drupal\filter\Plugin\FilterBase;
use Drupal\filter\Plugin\FilterInterface;

/**
 * Restores the USWDS summary box heading id after heading id rewriting.
 *
 * Markup is rendered with aria-labelledby and heading id set to
 * summary-box-{heading}. The heading id filter then rewrites h2-h6 ids.
 * This filter copies aria-labelledby back onto the heading so the pair
 * stays the USWDS id.
 */
#[Filter(
  id: 'ec_uswds_summary_box_labelledby',
  title: new TranslatableMarkup('Keep USWDS summary box aria-labelledby in sync with heading ids'),
  type: FilterInterface::TYPE_TRANSFORM_IRREVERSIBLE,
  weight: 11,
)]
class SummaryBoxLabelledByFilter extends FilterBase {

  /**
   * {@inheritdoc}
   */
  public function process($text, $langcode): FilterProcessResult {
    if (!str_contains((string) $text, 'usa-summary-box')) {
      return new FilterProcessResult($text);
    }

    $document = Html::load($text);
    $xpath = new \DOMXPath($document);
    foreach ($xpath->query('//*[@class and contains(concat(" ", normalize-space(@class), " "), " usa-summary-box ")]') as $box) {
      if (!$box instanceof \DOMElement) {
        continue;
      }
      $heading = $xpath->query('.//*[@class and contains(concat(" ", normalize-space(@class), " "), " usa-summary-box__heading ")]', $box)->item(0);
      if (!$heading instanceof \DOMElement) {
        continue;
      }
      $labelled_by = $box->getAttribute('aria-labelledby');
      if ($labelled_by === '') {
        continue;
      }
      $heading->setAttribute('id', $labelled_by);
    }

    return new FilterProcessResult(Html::serialize($document));
  }

}
