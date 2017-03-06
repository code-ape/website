#!/usr/bin/env bash


CMD="$1"

HOST="${HOST:-devbox}"
PROTOCOL="${PROTOCOL:-http}"
SITE_PATH="${SITE_PATH:-public}"

PORT="${PORT:-8000}"
if [[ ! -z $PORT ]]; then
	PORT_WITH_COLON=":$PORT"
fi

case "$CMD" in
	serve)
		cmd="hugo server -w --renderToDisk -b ${HOST}/${SITE_PATH} -p $PORT"
		echo "Running: $cmd"
		eval $cmd
		;;
	build)
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
