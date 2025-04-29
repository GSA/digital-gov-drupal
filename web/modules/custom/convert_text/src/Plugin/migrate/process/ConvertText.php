<?php

namespace Drupal\convert_text\Plugin\migrate\process;

use Drupal\convert_text\ConvertText as Converter;
use Drupal\migrate\Attribute\MigrateProcess;
use Drupal\migrate\MigrateExecutableInterface;
use Drupal\migrate\ProcessPluginBase;
use Drupal\migrate\Row;

/**
 * Wraps the ConvertText functionality for use as process step.
 *
 * Usage:
 *
 * body/value:
 *  plugin: dg_convert_text
 *  source: body
 *  field_type: (html|html_no_breaks|plain_text)
 */
#[MigrateProcess(
  id: "dg_convert_text",
)]
class ConvertText extends ProcessPluginBase {

  /**
   * Calls the convert text method for the field type being processed.
   */
  public function transform($value, MigrateExecutableInterface $migrate_executable, Row $row, $destination_property) {

    switch ($this->configuration['field_type']) {
      case 'html':
        return Converter::htmlText($value);

      case 'html_no_breaks':
        return Converter::htmlNoBreaksText($value);

      case 'plain_text':
        return Converter::plainText($value);

      default:
        throw new \InvalidArgumentException('Missing or unknown field type');

    }
  }

}
