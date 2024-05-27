#!/usr/bin/bash

# repos to respect
BASEDIR=$(dirname $(readlink -f $0))/..
REPOS="osbuild-getting-started osbuild osbuild-composer images image-builder image-builder-frontend weldr-client"
REPOS="$REPOS pulp-client community-gateway"

ARGS=${*:-status --branch --short}

NUM="$(echo $REPOS | wc -w)"
I=0
running_jobs=0
MAX_PARALLEL=4
tmp_files=()

function run_git_command {
  local dir=$1
  local args=$2
  local tmp_file=$3
  git -c color.status=always -C "$dir" $args >> "$tmp_file" 2>&1 &
}

for D in $REPOS; do
  I=$(( $I + 1 ))
  FULL_DIR="$BASEDIR/$D"
  if [ "$ARGS" == "walk" ]; then
    echo "  ------------- ( $I / $NUM ) $D -------------"
    pushd $FULL_DIR
    git status
    bash
    popd
  else
    tmp_file=$(mktemp)
    tmp_files+=("$tmp_file")
    echo "  ------------- ( $I / $NUM ) $D -------------" > "$tmp_file"
    echo "  -- Started -- ( $I / $NUM ) $D -------------"
    run_git_command "$FULL_DIR" "$ARGS" "$tmp_file"

    (( running_jobs++ ))
    if (( running_jobs >= MAX_PARALLEL )); then
      wait -n
      (( running_jobs-- ))
    fi
  fi
done

if [ "$ARGS" != "walk" ]; then
  wait
fi

echo "  ------------- DONE -------------"

# Print the buffered output
for tmp_file in "${tmp_files[@]}"; do
  echo ""
  cat "$tmp_file"
  rm "$tmp_file"
done

