#!/usr/bin/env bash
files="$@"
mkdir -p ../scratchpad/geography/towns
cp -t ../scratchpad/geography/towns $files
cd ../scratchpad
git add geography
git commit -m "Update topojson files - towns"
git push

if ! gh release view geos-town > /dev/null 2>&1; then
  gh release create geos-town --title "Town shapefiles" --notes ""
fi

# return to previous directory
cd -

gh release upload geos-town \
  $files \
  --repo "CT-Data-Haven/scratchpad" \
  --clobber 

gh release view geos-town \
  --repo "CT-Data-Haven/scratchpad" \
  --json id,tagName,assets,createdAt,url > \
  .shapes_uploaded.json