#!/usr/bin/env bash

set -e

CMD="$1"

HOST="${HOST:-localhost}"
PROTOCOL="${PROTOCOL:-http}"
SITE_PATH="${SITE_PATH:-}"

PORT="${PORT:-3000}"
if [[ ! -z $PORT ]]; then
	PORT_WITH_COLON=":$PORT"
fi

case "$CMD" in
	serve)
		cmd="hugo server -w --renderToDisk -b ${HOST}/${SITE_PATH} -p $PORT"
		echo "Running: $cmd"
		eval $cmd
		;;
	serve_drafts)
		cmd="hugo server -w -D --renderToDisk -b ${HOST}/${SITE_PATH} -p $PORT"
		echo "Running: $cmd"
		eval $cmd
		;;
	build)
		cmd="hugo -b ${PROTOCOL}://${HOST}${PORT_WITH_COLON}/${SITE_PATH}"
		echo "Running: $cmd"
		eval $cmd
		;;
	build_gh_pages)
		HOST="ferrisellis.com"
		PROTOCOL="https"
		SITE_PATH=""
		PORT_WITH_COLON=""
		echo "Removing public/"
		rm -rf public || true 
		echo "Pruning git worktree"
		git worktree prune
		echo "Adding git worktree of gh-pages at public/"
		git worktree add -B gh-pages public origin/gh-pages
		cmd="hugo -b ${PROTOCOL}://${HOST}${PORT_WITH_COLON}/${SITE_PATH}"
		echo "Running: $cmd"
		eval $cmd
		;;
	build_watch)
		cmd="hugo -w -b ${PROTOCOL}://${HOST}${PORT_WITH_COLON}/${SITE_PATH}"
		echo "Running: $cmd"
		eval $cmd
		;;
	build_watch_drafts)
		cmd="hugo -w -D -b ${PROTOCOL}://${HOST}${PORT_WITH_COLON}/${SITE_PATH}"
		echo "Running: $cmd"
		eval $cmd
		;;
	*)
		echo "Command '$CMD' isn't valid!"
		;;
esac
