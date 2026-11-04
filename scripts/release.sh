#!/usr/bin/env bash
# Prepares a release: sets the version in the spec file, adds the changes to
# the changelog, commits both and creates an annotated tag with the changes.
# Shows a preview first and changes nothing until confirmed. Never pushes.
#
# Usage: scripts/release.sh [major|minor|patch|X.Y.Z]

set -euo pipefail

cd "$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"

SPEC=rpm/harbour-flowplayer-ng.spec
CHANGES=rpm/harbour-flowplayer-ng.changes

die() {
    echo "Error: $*" >&2
    exit 1
}

# Accepts major, minor, patch or an explicit version, prints the new version
resolve_version() {
    local major minor patch
    IFS=. read -r major minor patch <<< "$current"
    case "$1" in
        major) echo "$((major + 1)).0.0" ;;
        minor) echo "$major.$((minor + 1)).0" ;;
        patch) echo "$major.$minor.$((patch + 1))" ;;
        *) echo "$1" ;;
    esac
}

check_version() {
    [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Not a valid version: $1" >&2; return 1; }
    if [ "$1" = "$current" ] || [ "$(printf '%s\n%s\n' "$current" "$1" | sort -V | tail -n 1)" != "$1" ]; then
        echo "Version must be newer than $current: $1" >&2
        return 1
    fi
    if git rev-parse -q --verify "refs/tags/v$1" > /dev/null; then
        echo "Tag v$1 already exists" >&2
        return 1
    fi
}

read_changes() {
    local line
    changes=()
    echo "Changes in $version, one per line. Empty line to finish:"
    while IFS= read -r -e -p "- " line; do
        # A pasted list may already have its bullets
        line=$(sed -E 's/^[[:space:]]*([-*][[:space:]]+)?//; s/[[:space:]]+$//' <<< "$line")
        if [ -z "$line" ]; then
            [ "${#changes[@]}" -gt 0 ] && return 0
            echo "Enter at least one change."
            continue
        fi
        changes+=("$line")
    done
    [ "${#changes[@]}" -gt 0 ] || die "No changes entered"
}

preview() {
    local branch dirty
    branch=$(git branch --show-current)
    dirty=$(git status --short)

    echo
    echo "==================== PREVIEW ===================="
    echo "Version: $current -> $version ($SPEC)"
    echo
    echo "Added at the top of $CHANGES:"
    sed 's/^/    /' <<< "$entry"
    echo
    echo "Commit on ${branch:-detached HEAD}: \"version bump\" (only the two files above)"
    echo
    echo "Annotated tag $tag:"
    sed 's/^/    /' <<< "$message"
    echo
    echo "Nothing will be pushed."
    if [ "$branch" != "devel" ]; then
        echo
        echo "WARNING: you are on '${branch:-detached HEAD}', not on 'devel'."
    fi
    if [ -n "$dirty" ]; then
        echo
        echo "WARNING: these uncommitted changes will NOT be part of $tag:"
        sed 's/^/    /' <<< "$dirty"
    fi
    echo "================================================="
}

[ -f "$SPEC" ] && [ -f "$CHANGES" ] || die "Spec or changes file not found"
git diff --quiet HEAD -- "$SPEC" "$CHANGES" ||
    die "$SPEC or $CHANGES has uncommitted changes: commit or discard them first"

current=$(sed -n -E 's/^Version:[[:space:]]*//p' "$SPEC" | head -n 1)
[[ $current =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Cannot read the version from $SPEC: '$current'"

# The changelog keeps its own author line, which differs from the git identity
author=$(grep -m 1 '^\* ' "$CHANGES" | sed -E 's/^\* [A-Za-z]+ [A-Za-z]+ [0-9]+ [0-9]+ (.*) - [^ ]+$/\1/')
[[ $author == *"<"*">" ]] || die "Cannot read the author from the last entry of $CHANGES"

echo "Current version: $current"
if [ $# -gt 1 ]; then
    die "Usage: $0 [major|minor|patch|X.Y.Z]"
elif [ $# -eq 1 ]; then
    version=$(resolve_version "$1")
    check_version "$version" || exit 1
else
    while :; do
        IFS= read -r -e -p "New version (major, minor, patch or X.Y.Z): " answer || die "No version entered"
        version=$(resolve_version "$answer")
        check_version "$version" && break
    done
fi
tag="v$version"

while :; do
    read_changes
    bullets=$(printf -- '- %s\n' "${changes[@]}")
    # rpm requires English day and month names
    entry="* $(LC_ALL=C date '+%a %b %-d %Y') $author - $version"$'\n'"$bullets"
    message="Version $version"$'\n'"$bullets"

    preview

    answer=""
    IFS= read -r -p "Apply? [y]es / [r]e-enter changes / [N]o: " answer || true
    case "$answer" in
        y|Y|yes) break ;;
        r|R) echo ;;
        *) echo "Cancelled, nothing was changed."; exit 0 ;;
    esac
done

sed -i -E "s/^(Version:[[:space:]]*).*/\1$version/" "$SPEC"
{ printf '%s\n\n' "$entry"; git show "HEAD:$CHANGES"; } > "$CHANGES.new"
cat "$CHANGES.new" > "$CHANGES"
rm -f "$CHANGES.new"

if ! git commit -q -m "version bump" -- "$SPEC" "$CHANGES"; then
    git restore -- "$SPEC" "$CHANGES"
    die "The commit failed: the spec and changes files were restored"
fi

git tag -a "$tag" -F - <<< "$message" ||
    die "The commit was made but tag $tag could not be created"

echo
echo "Done: $(git log -1 --format='%h %s') tagged $tag."
echo "To publish it (pushing the tag starts the CI builds):"
echo "    git push origin $(git branch --show-current) $tag"
