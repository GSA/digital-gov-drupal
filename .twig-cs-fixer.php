<?php


$ruleset = new TwigCsFixer\Ruleset\Ruleset();

// You can start from a default standard
$ruleset->addStandard(new TwigCsFixer\Standard\TwigCsFixer());

// And then add/remove/override some rules
// $ruleset->addRule(new TwigCsFixer\Rules\File\FileExtensionRule());
// $ruleset->removeRule(TwigCsFixer\Rules\Whitespace\EmptyLinesRule::class);
// Use 2 spaces instead of 4.
$ruleset->overrideRule(new TwigCsFixer\Rules\Whitespace\IndentRule(2, false));

$config = new TwigCsFixer\Config\Config();
$config->setRuleset($ruleset);

$finder = new TwigCsFixer\File\Finder();
$finder->in(['web/themes/custom', 'web/modules/custom']);

$config->setFinder($finder);

return $config;