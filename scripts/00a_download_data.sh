#!/usr/bin/env bash

acsyr=$1
cdcyr=$2
cwsyr=$3

# download assets from latest releases of cdc_aggs (tagged v$cdcyr) and $acsyracs (tagged dist)
# comparable to input_data/acs_nhoods_by_city_$(YR).rds input_data/cdc_health_all_lvls_nhood_$(YR).rds 
# updating to get cws data from town equity data repo
acsrepo="CT-Data-Haven/$1acs"
cdcrepo="CT-Data-Haven/cdc_aggs"
scratchrepo="CT-Data-Haven/scratchpad"
# equitrepo="CT-Data-Haven/towns$equityr"
mrprepo="CT-Data-Haven/mrp"

acstag="dist"
cdctag="v$cdcyr"
scratchtag="meta"
mrptag="dcws$cwsyr"

gh release download "$acstag" \
  --repo "$acsrepo" \
  --pattern "acs_town_*.rds" \
  --dir input_data \
  --clobber

gh release download "$cdctag" \
  --repo "$cdcrepo" \
  --pattern "*.rds" \
  --dir input_data \
  --clobber

gh release download "$scratchtag" \
  --repo "$scratchrepo" \
  --pattern "acs_indicator_headings.txt" \
  --pattern "cdc_indicators.txt" \
  --pattern "mrp_cws_indicator_headings.txt" \
  --dir _utils \
  --clobber

# gh release download "$equittag" \
#   --repo "$equitrepo" \
#   --pattern "data.zip" \
#   --dir input_data \
#   --clobber

gh release download "$mrptag" \
  --repo "$mrprepo" \
  --pattern "*.csv" \
  --dir input_data \
  --clobber

# extract cws files from town equity data, delete zip file
# unzip -o -j input_data/data.zip \
#   data/health/cws_1521_health_race.csv \
#   data/civic/cws_1521_civic_by_loc.csv \
#   data/environ/cws_1521_walkability_race.csv \
#   -d input_data 

# rm input_data/data.zip

# make flag file
gh release view "$scratchtag" \
  --repo "$scratchrepo" \
  --json id,tagName,assets,createdAt,url > \
  .meta_downloaded.json