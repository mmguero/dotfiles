#!/usr/bin/env bash

# "git clone" all of a GitHub user's or organization's repositories (up to 100)
# if the repo is a GitHub fork, add the parent fork as an upstream remote.

ENCODING="utf-8"

function print_usage() {
  echo "Usage: $(basename $0)" >&2
  echo -e "\t -v\t(optional)\tverbose bash\t\tdefault FALSE" >&2
  echo -e "\t -e\t(optional)\tfail on first error\tdefault FALSE" >&2
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

GIT_API_URL_PREFIX="https://api.github.com"
GIT_CLONE_URL_PREFIX="https://github.com/"
GIT_CLONE_URL_SUFFIX=""
UPSTREAM_NAME=upstream
REMOTE_NAME=
TOKEN=${GITHUB_OAUTH_TOKEN:-""}
API_ENTITY_NAME=
API_ENTITY_TYPE=

while getopts 'vegt:o:u:r:p:' OPTION; do
  case "$OPTION" in

    # enable verbose bash execution tracing
    v)
      set -x
      ;;

    # exit on any process error
    e)
      set -e
      ;;

    # use git@ instead of https:// to checkout
    g)
      GIT_CLONE_URL_PREFIX="git@github.com:"
      GIT_CLONE_URL_SUFFIX=".git"
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

# retrieve and loop through the organization's|user's repositories
for REPO_NAME in $(curl -sSL -H "Authorization: token $TOKEN" "$GIT_API_URL_PREFIX/$API_ENTITY_TYPE/$API_ENTITY_NAME/repos?per_page=100" | \
                   jq -r '.[] | .html_url' | \
                   sed "s/.*github\.com\///g" | \
                   sort -u); do

  # do the clone
  PROJECT_NAME="$(basename "$REPO_NAME")"
  git clone -o "$REMOTE_NAME" --recursive "${GIT_CLONE_URL_PREFIX}${REPO_NAME}${GIT_CLONE_URL_SUFFIX}" ./"$PROJECT_NAME" || continue
  pushd ./"$PROJECT_NAME" >/dev/null 2>&1

  # if there is a fork, set up the upstream remote
  PARENT_FORK_URL="$(curl -f -sSL -H "Authorization: token $TOKEN" "$GIT_API_URL_PREFIX/repos/$REPO_NAME?per_page=100" | jq -r '.parent.html_url' 2>/dev/null)"
  if [[ -n $PARENT_FORK_URL ]] && [[ $PARENT_FORK_URL != "null" ]]; then
    git remote add "$UPSTREAM_NAME" "$PARENT_FORK_URL"
    git remote set-url --push "$UPSTREAM_NAME" no_push
    git fetch "$UPSTREAM_NAME"
  fi

  git fetch --all
  popd >/dev/null 2>&1

done # end repositories loop

