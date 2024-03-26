#!/usr/bin/bash

# repos to respect
BASEDIR=$(dirname $(readlink -f $0))/..
REPOS="osbuild-getting-started osbuild osbuild-composer images image-builder image-builder-frontend weldr-client"
REPOS="$REPOS pulp-client community-gateway"

ARGS=${*:-status --branch --short}

NUM="$(echo $REPOS | wc -w)"
I=0
for D in $REPOS; do
  I=$(( $I + 1 ))
  echo ""
  echo "  ------------ ( $I / $NUM ) $D ------------"
  FULL_DIR="$BASEDIR/$D"
  if [ "$ARGS" == "walk" ]; then
    pushd $FULL_DIR
    git status
    bash
    popd
  else
    git -C "$FULL_DIR" $ARGS
  fi
done
if [ "$ARGS" == "walk" ]; then
  echo "  ------------ DONE ------------"
fi
