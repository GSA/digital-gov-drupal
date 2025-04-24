<?php

namespace Drupal\dg_tome\EventSubscriber;

use Drupal\tome_static\Event\CollectPathsEvent;
use Drupal\tome_static\Event\PathPlaceholderEvent;
use Drupal\tome_static\Event\TomeStaticEvents;
use Symfony\Component\EventDispatcher\EventSubscriberInterface;

/**
 * This event subscriber modifies static site generation.
 */
class TomeEventSubscriber implements EventSubscriberInterface {

  /**
   * Listener for the CollectPathsEvent.
   */
  public function excludePaths(CollectPathsEvent $event): void {
    $paths = $event->getPaths(TRUE);

    foreach ($paths as $path => $metadata) {
      if ($this->isLocalWithTrailingSlash($path)) {
        unset($paths[$path]);
      }

      // Ignore relative or malformed links.
      if (str_starts_with($path, '/') && !str_ends_with($path, '/')) {
        unset($paths[$path]);
      }
    }

    $event->replacePaths($paths);
  }

  /**
   * Adds site-wide alert path.
   */
  public function addAlertPaths(CollectPathsEvent $event): void {
    $event->addPath(
      '/sitewide_alert/load',
    );
  }

  /**
   * Prevent exporting paths Tome might discover after the collect paths event.
   */
  public function excludeInvalidPaths(PathPlaceholderEvent $event): void {
    $path = $event->getPath();
    if (str_starts_with($path, '_redirect:')
      || str_starts_with($path, '_entity:')
    ) {
      return;
    }

    if ($path === 'about:blank') {
      $event->setInvalid();
    }

    if ($this->isLocalWithTrailingSlash($path)) {
      $path = rtrim($path, '/');
      $event->setPath($path);
    }

    if (!str_starts_with($path, '/')) {
      $event->setInvalid();
    }
  }

  /**
   * Checks if a path is local with a trailing slash.
   *
   * Tome should never request any local path with a trailing-slash.
   * If it does request it, that is because the path was found in the content
   * of a node or term. For example, when tome runs and finds a link to
   * `/communities/multilingual/`, Drupal will redirect the request to the
   * path without the trailing slash. The response causes Tome to
   * save it the contents as a refresh redirect and overwrite what it already
   * exported.
   */
  private function isLocalWithTrailingSlash(string $path): bool {
    // Don't accidentally exclude the homepage.
    return $path !== '/' && str_ends_with($path, '/');
  }

  /**
   * {@inheritdoc}
   */
  public static function getSubscribedEvents() {
    $events[TomeStaticEvents::COLLECT_PATHS][] = ['excludePaths'];
    $events[TomeStaticEvents::COLLECT_PATHS][] = ['addAlertPaths'];
    $events[TomeStaticEvents::PATH_PLACEHOLDER][] = ['excludeInvalidPaths'];
    return $events;
  }

}
