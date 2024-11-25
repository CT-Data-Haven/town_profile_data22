#!/usr/bin/env bash
# given name of repo, pattern to match in tag name, and output flag file:
# look up list of releases for that repo, get most recent matching tag
# if flag already exists:
#   if current release is newer than flagged release --> should update
# if flag doesn't exist: --> should update
# write out current release's tag and date to flag file
# return whether to update
repo=$1
tagpatt=$2
flag=$3
need_update=1

current=$(gh release list --repo "$repo" --json tagName,publishedAt | 
    jq -r --arg tagpatt "$tagpatt" '[.[] | select(.tagName | contains($tagpatt))] | max_by(.publishedAt) | {tagName, publishedAt}')
currdate=$(echo "$current" | jq -r ".publishedAt")

# if flag file exists, check date
if [ -f "$flag" ]; then
    flagdate=$(jq ".publishedAt" "$flag")
    # if [[ "$currdate" < "$flagdate" ]]; then
    if [[ ! "$flagdate" > "$currdate" ]]; then
        need_update=0
    fi
fi

# add need_update to current json
current=$(echo "$current" | jq ".update = $need_update")

if [ "$need_update" -eq 1 ]; then
    echo "$current" > "$flag"
fi
echo "$current"