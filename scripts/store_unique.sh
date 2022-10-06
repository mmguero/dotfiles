#!/usr/bin/env bash

# create an SQLite3 database and store a unique value in it

set -e
set -u
set -o pipefail

ENCODING="utf-8"

# parse command-line options
DATABASE_FILESPEC=""
TABLE_NAME=mesa
FIELD_NAME=campo
VALUE=""
while getopts 'v:d:t:f:' OPTION; do
  case "$OPTION" in
    v)
      VALUE="$OPTARG"
      ;;

    d)
      DATABASE_FILESPEC="$OPTARG"
      ;;

    t)
      TABLE_NAME="$OPTARG"
      ;;

    f)
      FIELD_NAME="$OPTARG"
      ;;

    ?)
      echo "script usage: $(basename $0) -d database.db -t table -f field -v value" >&2
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

# cross-platform GNU gnonsense for core utilities
[[ "$(uname -s)" = 'Darwin' ]] && REALPATH=grealpath || REALPATH=realpath
[[ "$(uname -s)" = 'Darwin' ]] && DIRNAME=gdirname || DIRNAME=dirname
if ! (command -v "$REALPATH" && command -v "$DIRNAME" && command -v sqlite3) > /dev/null; then
  echo "$(basename "${BASH_SOURCE[0]}") requires $REALPATH and $DIRNAME and sqlite3"
  exit 1
fi
SCRIPT_PATH="$($DIRNAME $($REALPATH -e "${BASH_SOURCE[0]}"))"

# get database filename and directory to use, and specify a lock directory for a singleton
[[ -z "$DATABASE_FILESPEC" ]] && DATABASE_FILESPEC="$SCRIPT_PATH"/database.db
DATABASE_DIR="$($DIRNAME "${DATABASE_FILESPEC}")"

# make sure only one instance of the script
LOCK_DIR="${DATABASE_DIR}/$(basename "$DATABASE_FILESPEC")_lock"
function finish {
    rmdir -- "$LOCK_DIR" || echo "Failed to remove lock directory '$LOCK_DIR'" >&2
}

if mkdir -- "$LOCK_DIR" 2>/dev/null; then
    trap finish EXIT
    pushd "$DATABASE_DIR" >/dev/null 2>&1

    if [[ -n "$VALUE" ]]; then
        sqlite3 "$(basename "$DATABASE_FILESPEC")" <<EOF
CREATE TABLE IF NOT EXISTS \`$TABLE_NAME\` (id INTEGER PRIMARY KEY, timestamp DATE DEFAULT (datetime('now','localtime')), \`$FIELD_NAME\` text UNIQUE);
INSERT INTO \`$TABLE_NAME\` (\`$FIELD_NAME\`) VALUES ('$VALUE') ON CONFLICT(\`$FIELD_NAME\`) DO UPDATE SET timestamp=datetime('now','localtime');
SELECT * FROM \`$TABLE_NAME\` WHERE (\`$FIELD_NAME\` == '$VALUE');
EOF
    fi

    popd >/dev/null 2>&1
    finish
    trap - EXIT
fi # singleton lock check
