#!/bin/bash

set -xe

# Ensure in the app directory.
cd "$(dirname "$0")"

DRUSH_BIN="./drush.sh"
[ -n "$VCAP_APPLICATION" ] && DRUSH_BIN="drush"

declare -a MIGS=("json_authors"
    "json_communities" "json_community_logos" "json_events" "json_files"
    "json_files_to_media" "json_guide_navs" "json_guide_navs__navigation"
    "json_guides" "json_hcd_landing" "json_images" "json_images_to_media"
    "json_news" "json_pages" "json_resources" "json_s3_files" "json_s3_files_to_media"
    "json_short_posts" "json_sources" "json_sources__logos" "json_sources__media"
    "json_topics" "json_topics__featured_links" "json_topics__featured_links_ext"
    "json_topics__resource_paragraphs"
)
for SRC in "${MIGS[@]}"
do
   ${DRUSH_BIN} migrate:messages "$SRC"
done
