#!/bin/bash
# Compacts the TDB2 datasets one by one and deletes the old generation right after each one,
# smallest datasets first, so that the disk is freed progressively. The image's
# docker-compact-entrypoint.sh compacts every dataset before deleting any old generation, which
# needs the compacted size of all datasets in free space.
#
# Called by compact-datasets.sh, inside the Fuseki image, with all containers stopped.
#
# Only datasets bigger than MIN_SIZE_MB (first argument, default 20) are compacted: there is one
# JVM per compaction, and compacting thousands of small datasets would take hours for little gain.

set -u

MIN_SIZE_MB=${1:-20}
MARGIN_MB=1024
DATABASES=/fuseki/databases

free_mb() {
  df -Pm "$DATABASES" | awk 'NR==2 {print $4}'
}

cd "$DATABASES" || exit 1

echo "$(date -u) Start, $(free_mb) MB free, compacting datasets > ${MIN_SIZE_MB} MB"

compacted=0
failed=()
skipped=()

for dataset in $(du -sm -- */ | sort -n | awk -v min="$MIN_SIZE_MB" '$1 > min {print $2}'); do
  dataset=${dataset%/}
  generations=$(find "$dataset" -maxdepth 1 -type d -name 'Data-*' | sort)
  count=$(echo "$generations" | grep -c .)

  if [ "$count" -ne 1 ]; then
    # Several generations: an earlier compaction was interrupted, don't guess which one is good
    echo "SKIP $dataset: $count generations ($(echo $generations))"
    skipped+=("$dataset")
    continue
  fi

  size=$(du -sm "$dataset" | cut -f1)
  free=$(free_mb)
  # The compacted generation is never bigger than the current one: with that much free space,
  # the disk can't get full in the middle of a compaction
  if [ "$free" -lt $((size + MARGIN_MB)) ]; then
    echo "SKIP $dataset (${size} MB): only ${free} MB free"
    skipped+=("$dataset")
    continue
  fi

  old=$(echo "$generations" | tail -1)
  echo "Compacting $dataset (${size} MB, ${free} MB free)..."
  if /jena-fuseki/bin/tdb2.tdbcompact --loc="$dataset"; then
    new=$(find "$dataset" -maxdepth 1 -type d -name 'Data-*' | sort | tail -1)
    # Only delete the old generation if a new, non-empty one was really written
    if [ "$new" != "$old" ] && [ -s "$new/nodes.dat" ] && [ -s "$new/SPO.dat" ] && [ "$(free_mb)" -gt 0 ]; then
      rm -rf "$old"
      echo "  -> $(du -sm "$dataset" | cut -f1) MB, $(free_mb) MB free"
      compacted=$((compacted + 1))
    else
      echo "  UNEXPECTED RESULT ($old -> $new), nothing deleted, check it by hand"
      failed+=("$dataset")
    fi
  else
    # Remove the partial new generation, keep the original one
    echo "  FAILED, removing the new generation"
    find "$dataset" -maxdepth 1 -type d -name 'Data-*' | sort | tail -n +2 | xargs -r rm -rf
    failed+=("$dataset")
  fi
done

echo "$(date -u) Done: $compacted compacted, ${#failed[@]} failed, ${#skipped[@]} skipped, $(free_mb) MB free"
[ ${#failed[@]} -gt 0 ] && echo "Failed: ${failed[*]}"
[ ${#skipped[@]} -gt 0 ] && echo "Skipped: ${skipped[*]}"
exit 0
