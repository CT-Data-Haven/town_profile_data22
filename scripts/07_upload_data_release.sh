#!/usr/bin/env bash
# data="$1"
# headings="$2"
# notes="$3"
files="$@"

# is there already a release called viz? if not, create it
if ! gh release view viz > /dev/null 2>&1; then
  gh release create viz --title "Data and metadata for town viz" --notes ""
fi

gh release upload viz \
  $files \
  --clobber

gh release view viz \
  --json id,tagName,assets,createdAt,url > \
  .viz_uploaded.json
