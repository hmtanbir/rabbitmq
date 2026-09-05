#!/bin/bash

if [ -n "$1" ]; then
    NEW_VERSION="$1"
else
    read -p "Enter new version: " NEW_VERSION
fi

if [ -z "$NEW_VERSION" ]; then
    echo "No version provided. Exiting."
    exit 1
fi

if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid version format: $NEW_VERSION (expected X.Y.Z)"
    exit 1
fi

update_file() {
    local file="$1"
    local token="$2"
    local current next

    current=$(grep -oE "[${token}]=[0-9]+\.[0-9]+\.[0-9]+" "$file")
    if [ -z "$current" ]; then
        current=$(grep -oE "${token}[ ]*:[ ]*[0-9]+\.[0-9]+\.[0-9]+" "$file")
    fi

    next=${current#*=}
    [ "$next" = "$current" ] && next=${next#*:}
    current_ver=${next// /}

    if [ -z "$current_ver" ]; then
        echo "ERROR: no version found for \"$token\" in $file"
        return 1
    fi

    sed "s/${current_ver}/${NEW_VERSION}/g" "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    echo "Updated $file: $current_ver -> $NEW_VERSION"
}

exit_code=0
update_file "Dockerfile" "DRAGONFLY_VERSION" || exit_code=1
update_file ".github/workflows/deploy.yml" "IMAGE_TAG" || exit_code=1

[ "$exit_code" -eq 0 ] && echo "Done." || echo "Finished with errors."
exit "$exit_code"