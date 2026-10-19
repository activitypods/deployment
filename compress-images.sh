#!/bin/bash
# Recompresses the uploaded images bigger than MAX_KB (PROFILE_MAX_KB for profile pictures and
# actor icons), keeping their format and file name since they are referenced by the Pods.
# Originals are copied to ORIGINALS_DIR before being replaced.
#
# Usage: ./compress-images.sh [--dry-run]

set -eu

cd "$(dirname "$0")"

MAX_KB=${MAX_KB:-1024}
PROFILE_MAX_KB=${PROFILE_MAX_KB:-200}
UPLOADS_DIR=${UPLOADS_DIR:-./data/backend/uploads}
ORIGINALS_DIR=${ORIGINALS_DIR:-./data/uploads-originals}
FUSEKI_URL=${FUSEKI_URL:-http://localhost:3030}
DRY_RUN=$([ "${1:-}" = "--dry-run" ] && echo 1 || echo 0)

FUSEKI_PASSWORD=$(grep -E '^FUSEKI_PASSWORD=' .env | cut -d= -f2-)

PROFILE_LIST=$(mktemp)
trap 'rm -f "$PROFILE_LIST"' EXIT

QUERY='SELECT DISTINCT ?url WHERE {
  GRAPH ?g {
    { ?s <http://www.w3.org/2006/vcard/ns#photo> ?url }
    UNION { ?s <https://www.w3.org/ns/activitystreams#icon> ?url }
    UNION { ?s <https://www.w3.org/ns/activitystreams#icon> ?icon . ?icon <https://www.w3.org/ns/activitystreams#url> ?url }
  }
  FILTER(isIRI(?url))
}'

echo "Looking for profile pictures..."
for dir in "$UPLOADS_DIR"/*/; do
  dataset=$(basename "$dir")
  curl -sf -u "admin:$FUSEKI_PASSWORD" -H 'Accept: text/csv' --data-urlencode "query=$QUERY" \
    "$FUSEKI_URL/$dataset/query" | tail -n +2 | tr -d '\r' | sed -E 's|^https?://[^/]+||' >> "$PROFILE_LIST" ||
    echo "WARN no dataset for $dataset"
done
echo "$(sort -u "$PROFILE_LIST" | wc -l) profile pictures found"

mkdir -p "$ORIGINALS_DIR"

docker run --rm -i --platform linux/amd64 --cpus 1 \
  -v "$(realpath "$UPLOADS_DIR")":/uploads \
  -v "$(realpath "$ORIGINALS_DIR")":/originals \
  -v "$PROFILE_LIST":/profiles.txt:ro \
  -e MAX_KB="$MAX_KB" -e PROFILE_MAX_KB="$PROFILE_MAX_KB" -e DRY_RUN="$DRY_RUN" \
  alpine:3.20 sh -s <<'EOF'
set -eu
apk add -q --no-cache imagemagick imagemagick-jpeg imagemagick-webp > /dev/null

processed=0
failed=0
saved=0

compress() {
  file=$1 max=$(($2 * 1024)) sizes=$3
  rel=${file#/uploads/}
  size=$(stat -c %s "$file")
  [ "$size" -le "$max" ] && return 0

  if [ "$DRY_RUN" = 1 ]; then
    echo "$rel $((size / 1024)) KB > $(($max / 1024)) KB"
    processed=$((processed + 1))
    return 0
  fi

  case "$file" in
    *.png | *.PNG) format=PNG ;;
    *.webp | *.WEBP) format=WEBP ;;
    *) format=JPEG ;;
  esac
  tmp="$file.tmp"
  best=$size
  for dim in $sizes; do
    for quality in 85 75; do
      magick "$file" -auto-orient -strip -depth 8 -resize "${dim}x${dim}>" -quality "$quality" "$format:$tmp" 2> /dev/null || continue
      new=$(stat -c %s "$tmp")
      if [ "$new" -lt "$best" ]; then
        best=$new
        mv "$tmp" "$tmp.best"
      fi
      [ "$best" -le "$max" ] && break 2
    done
  done
  rm -f "$tmp"

  if [ ! -f "$tmp.best" ]; then
    echo "FAIL $rel"
    failed=$((failed + 1))
    return 0
  fi

  mkdir -p "/originals/$(dirname "$rel")"
  [ -e "/originals/$rel" ] || cp -p "$file" "/originals/$rel"
  owner=$(stat -c %u:%g "$file")
  mode=$(stat -c %a "$file")
  mv "$tmp.best" "$file"
  chown "$owner" "$file"
  chmod "$mode" "$file"

  echo "$rel $((size / 1024)) KB -> $((best / 1024)) KB$([ "$best" -gt "$max" ] && echo ' (still too big)')"
  processed=$((processed + 1))
  saved=$((saved + size - best))
}

find /uploads -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) > /tmp/files.txt

while read -r file; do
  if grep -qxF "/${file#/uploads/}" /profiles.txt; then
    compress "$file" "$PROFILE_MAX_KB" "1024 800 640 512 400"
  else
    compress "$file" "$MAX_KB" "3000 2560 2048 1600 1280 1024"
  fi
done < /tmp/files.txt

if [ "$DRY_RUN" = 1 ]; then
  echo "$processed images to compress"
else
  echo "$processed images compressed, $failed failed, $((saved / 1024 / 1024)) MB saved"
fi
EOF
