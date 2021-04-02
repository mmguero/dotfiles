#!/usr/bin/env bash

# "git clone" all of a GitHub user's or organization's repositories (up to 100)
# if the repo is a GitHub fork, add the parent fork as an upstream remote.

ENCODING="utf-8"

GIT_API_URL_PREFIX="https://api.github.com"
GIT_CLONE_URL_PREFIX="https://github.com/"
GIT_CLONE_URL_SUFFIX=""
UPSTREAM_NAME=upstream
REMOTE_NAME=
TOKEN=${GITHUB_OAUTH_TOKEN:-""}
API_ENTITY_NAME=
API_ENTITY_TYPE=
CLONE_ARCHIVED=false
MAX_MEGABYTES=50

function print_usage() {
  echo "Usage: $(basename $0)" >&2
  echo -e "\t -v\t(optional)\tverbose bash\t\tdefault FALSE" >&2
  echo -e "\t -e\t(optional)\tfail on first error\tdefault FALSE" >&2
  echo -e "\t -a\t(optional)\tclone archived repos\tdefault FALSE" >&2
  echo -e "\t -m #\t(optional)\tMaximum repo size (MB)\tdefault $MAX_MEGABYTES" >&2
  echo -e "\t -g\t(optional)\tgit@ vs. https:// clone\tdefault https://" >&2
  echo >&2
  echo -e "\t -t XXX\t\t\tGitHub OAUTH token\tdefault \$GITHUB_OAUTH_TOKEN env. variable" >&2
  echo >&2
  echo -e "\t -o\torganization name" >&2
  echo -e "\t OR" >&2
  echo -e "\t -u\tuser name" >&2
  echo >&2
  echo -e "\t -p XXX\t(optional)\tupstream remote name\tdefault \"upstream\"" >&2
}

while getopts 'vaegt:m:o:u:r:p:' OPTION; do
  case "$OPTION" in

    # enable verbose bash execution tracing
    v)
      set -x
      ;;

    # exit on any process error
    e)
      set -e
      ;;

    # exit on any process error
    a)
      CLONE_ARCHIVED=true
      ;;

    # use git@ instead of https:// to checkout
    g)
      GIT_CLONE_URL_PREFIX="git@github.com:"
      GIT_CLONE_URL_SUFFIX=".git"
      ;;

    # get maximum megabytes of repo to clone
    t)
      MAX_MEGABYTES="$OPTARG"
      ;;

    # specify GitHub OAUTH token (defaulted to $GITHUB_OAUTH_TOKEN above)
    t)
      TOKEN="$OPTARG"
      ;;

    # organization name, if organization
    o)
      API_ENTITY_NAME="$OPTARG"
      API_ENTITY_TYPE=orgs
      ;;

    # user name, if user
    u)
      API_ENTITY_NAME="$OPTARG"
      API_ENTITY_TYPE=users
      ;;

    # name for "origin" remote (defaults to the repository project name)
    r)
      REMOTE_NAME="$OPTARG"
      ;;

    # name for "upstream" remote (defaults to "upstream")
    p)
      UPSTREAM_NAME="$OPTARG"
      ;;

    ?)
      print_usage
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

if [[ -z $API_ENTITY_NAME ]] || [[ -z $TOKEN ]]; then
  # no organization/user or token
  print_usage
  exit 1
fi

# default "origin" remote to the repository project name
[[ -z $REMOTE_NAME ]] && REMOTE_NAME="$API_ENTITY_NAME"

MAX_KILOBYTES=$(( 1000*MAX_MEGABYTES ))

# retrieve and loop through the organization's|user's repositories
for REPO_NAME in $(curl -sSL -H "Authorization: token $TOKEN" "$GIT_API_URL_PREFIX/$API_ENTITY_TYPE/$API_ENTITY_NAME/repos?per_page=100" | \
                   jq -r '.[] | .html_url' | \
                   sed "s/.*github\.com\///g" | \
                   sort -u); do

  # get the information about the git repository (a JSON document)
  REPO_INFO_FILE="$(mktemp)"
  curl -f -sSL -H "Authorization: token $TOKEN" "$GIT_API_URL_PREFIX/repos/$REPO_NAME?per_page=100" > "$REPO_INFO_FILE"
  REPO_INFO_FILE_SIZE=$(stat -c%s "$REPO_INFO_FILE")
  if (( $REPO_INFO_FILE_SIZE > 100 )); then

    # get whether the repo is archived or not
    IS_ARCHIVED="$(cat "$REPO_INFO_FILE" | jq -r '.archived' 2>/dev/null)"

    # get repo size (stored in KB)
    REPO_SIZE_KILOBYTES="$(cat "$REPO_INFO_FILE" | jq -r '.size' 2>/dev/null)"

    if ( [[ "$CLONE_ARCHIVED" == "true" ]] || [[ "$IS_ARCHIVED" != "true" ]] ) && (( $REPO_SIZE_KILOBYTES <= $MAX_KILOBYTES )); then
      # do the clone
      PROJECT_NAME="$(basename "$REPO_NAME")"
      git clone -o "$REMOTE_NAME" --recursive "${GIT_CLONE_URL_PREFIX}${REPO_NAME}${GIT_CLONE_URL_SUFFIX}" ./"$PROJECT_NAME" || continue
      pushd ./"$PROJECT_NAME" >/dev/null 2>&1

      # if there is a fork, set up the upstream remote
      PARENT_FORK_URL="$(cat "$REPO_INFO_FILE" | jq -r '.parent.html_url' 2>/dev/null)"
      if [[ -n $PARENT_FORK_URL ]] && [[ $PARENT_FORK_URL != "null" ]]; then
        git remote add "$UPSTREAM_NAME" "$PARENT_FORK_URL"
        git remote set-url --push "$UPSTREAM_NAME" no_push
        git fetch "$UPSTREAM_NAME"
      fi

      git fetch --all
      popd >/dev/null 2>&1
    fi
  fi
  rm -f "$REPO_INFO_FILE"

done # end repositories loop

