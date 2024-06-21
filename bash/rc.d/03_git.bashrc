########################################################################
# git functions too unwieldy for .gitconfig
########################################################################

function current_git_branch () {
  (git symbolic-ref --short HEAD 2>/dev/null) | sed 's/development/dvl/' | sed 's/upstream/ups/' | sed 's/origin/org/' | sed 's/patch/pat/' | sed 's/topic/tpc/' | sed 's/feature/fea/' | sed 's/master/mas/'
}

function parse_git_remote_info () {
  (git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null) | sed 's/development/dvl/' | sed 's/upstream/ups/' | sed 's/origin/org/' | sed 's/patch/pat/' | sed 's/topic/tpc/' | sed 's/feature/fea/' | sed 's/master/mas/'
}

function parse_git_branch () {
  GIT_BRANCH=$(current_git_branch)
  if [ ! -z "$GIT_BRANCH" ]; then
    GIT_REMOTE=$(parse_git_remote_info)
    if [ ! -z "$GIT_REMOTE" ]; then
      echo "[$GIT_BRANCH:$GIT_REMOTE] "
    else
      echo "($GIT_BRANCH) "
    fi
  fi
}

function git_latest_release () {
  if [[ -n "$1" ]]; then
    GITHUB_API_CURL_ARGS=()
    GITHUB_API_CURL_ARGS+=( -fsSL )
    GITHUB_API_CURL_ARGS+=( -H )
    GITHUB_API_CURL_ARGS+=( "Accept: application/vnd.github.v3+json" )
    [[ -n "$GITHUB_TOKEN" ]] && \
      GITHUB_API_CURL_ARGS+=( -H ) && \
      GITHUB_API_CURL_ARGS+=( "Authorization: token $GITHUB_TOKEN" )
    (set -o pipefail && curl "${GITHUB_API_CURL_ARGS[@]}" "https://api.github.com/repos/$1/releases/latest" | jq '.tag_name' | sed -e 's/^"//' -e 's/"$//' ) || \
      (set -o pipefail && curl "${GITHUB_API_CURL_ARGS[@]}" "https://api.github.com/repos/$1/releases" | jq '.[0].tag_name' | sed -e 's/^"//' -e 's/"$//' ) || \
      echo unknown
  else
    echo unknown>&2
  fi
}

function git_release_download_counts () {
  if [[ -n "$1" ]]; then
    GITHUB_API_CURL_ARGS=()
    GITHUB_API_CURL_ARGS+=( -fsSL )
    GITHUB_API_CURL_ARGS+=( -H )
    GITHUB_API_CURL_ARGS+=( "Accept: application/vnd.github.v3+json" )
    [[ -n "$GITHUB_TOKEN" ]] && \
      GITHUB_API_CURL_ARGS+=( -H ) && \
      GITHUB_API_CURL_ARGS+=( "Authorization: token $GITHUB_TOKEN" )
    (set -o pipefail && curl "${GITHUB_API_CURL_ARGS[@]}" "https://api.github.com/repos/$1/releases" | jq 'reverse | [.[] | select(.assets | length > 0) | { tag_name: .tag_name, assets: [.assets[] | select(.download_count > 0) | { name: .name, download_count: .download_count }] }]' ) || \
      echo unknown
  else
    echo unknown>&2
  fi
}

function git_deep_search () {
  if [ "$1" ]; then
    PATTERN="$1"
    set -o pipefail && { find .git/objects/pack/ -name "*.idx" | while read i; do git show-index < "$i" | awk '{print $2}'; done; find .git/objects/ -type f | grep -v '/pack/' | awk -F'/' '{print $(NF-1)$NF}'; } | while read o; do git cat-file -p $o; done | grep -E "$PATTERN"
  else
    echo "No pattern specified">&2
  fi
}

function git_default_branch () {
  if [[ -n $GITHUB_TOKEN ]]; then
    REPO="$1"
    curl -sSL  -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" \
      "https://api.github.com/repos/$REPO" \
      | jq -r '.default_branch'
  else
    echo "\$GITHUB_TOKEN not defined">&2
  fi
}

function git_list_workflows () {
  if [[ -n $GITHUB_TOKEN ]]; then
    REPO="$1"
    curl -sSL  -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" \
      "https://api.github.com/repos/$REPO/actions/workflows" \
      | jq -r '.workflows | .[] | .id, .name' \
      | sed '$!N;s/\n/ /' \
      | sort -f -k 2,2 -t ' '
  else
    echo "\$GITHUB_TOKEN not defined">&2
  fi
}

function git_workflow_id () {
  if [[ -n $GITHUB_TOKEN ]]; then
    REPO="$1"
    WORKFLOW="$2"
    declare -A WORKFLOW_NAMES_TO_IDS
    while IFS= read -r line; do
        ID=$(echo "${line}" | cut -d' ' -f1)
        NAME=$(echo "${line}" | sed 's/^[^[:space:]]*[[:space:]]\{1,\}//')
        WORKFLOW_NAMES_TO_IDS["$NAME"]=$ID
    done <<< "$(git_list_workflows "$REPO")"
    echo "${WORKFLOW_NAMES_TO_IDS[$WORKFLOW]}"
  else
    echo "\$GITHUB_TOKEN not defined">&2
  fi
}

function git_workflow () {
  if [[ -n $GITHUB_TOKEN ]]; then
    REPO="$1"
    WORKFLOW="$2"
    [[ $1 == ?(-)+([0-9]) ]] || WORKFLOW=$(git_workflow_id "$REPO" "$WORKFLOW" )
    curl -sSL  -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" \
      "https://api.github.com/repos/$REPO/actions/workflows/$WORKFLOW"
  else
    echo "\$GITHUB_TOKEN not defined">&2
  fi
}

function git_list_workflow_runs () {
  if [[ -n $GITHUB_TOKEN ]]; then
    REPO="$1"
    WORKFLOW="$2"
    [[ $1 == ?(-)+([0-9]) ]] || WORKFLOW=$(git_workflow_id "$REPO" "$WORKFLOW" )
    curl -sSL  -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" \
      "https://api.github.com/repos/$REPO/actions/workflows/$WORKFLOW/runs"
  else
    echo "\$GITHUB_TOKEN not defined">&2
  fi
}

function git_latest_workflow_run_success () {
  if [[ -n $GITHUB_TOKEN ]]; then
    REPO="$1"
    WORKFLOW="$2"
    git_list_workflow_runs "$REPO" "$WORKFLOW" \
      | jq '.workflow_runs | map(select((.conclusion == "success") and (.status == "completed"))) | sort_by(.run_started_at) | last'
  else
    echo "\$GITHUB_TOKEN not defined">&2
  fi
}

function git_latest_workflow_run_in_progress () {
  if [[ -n $GITHUB_TOKEN ]]; then
    REPO="$1"
    WORKFLOW="$2"
    git_list_workflow_runs "$REPO" "$WORKFLOW" \
      | jq '.workflow_runs | map(select(.status == "in_progress")) | sort_by(.run_started_at) | last'
  else
    echo "\$GITHUB_TOKEN not defined">&2
  fi
}

function git_latest_workflow_run () {
  if [[ -n $GITHUB_TOKEN ]]; then
    REPO="$1"
    WORKFLOW="$2"
    git_list_workflow_runs "$REPO" "$WORKFLOW" \
      | jq '.workflow_runs | sort_by(.run_started_at) | last'
  else
    echo "\$GITHUB_TOKEN not defined">&2
  fi
}

function git_workflow_run_logs () {
  if [[ -n $GITHUB_TOKEN ]]; then
    REPO="$1"
    WORKFLOW="$2"
    RUN_ID="${3:-$(git_latest_workflow_run_success "$REPO" "$WORKFLOW" | jq -r '.id')}"
    curl -sSL -J -O -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" \
      "https://api.github.com/repos/$REPO/actions/runs/$RUN_ID/logs"
  else
    echo "\$GITHUB_TOKEN not defined">&2
  fi
}

function git_latest_artifacts () {
  if [[ -n $GITHUB_TOKEN ]]; then
    REPO="$1"
    WORKFLOW="$2"
    ARTIFACTS_URL="$(git_latest_workflow_run_success "$REPO" "$WORKFLOW" | jq '.artifacts_url' | tr -d '"')"
    if [[ -n "$ARTIFACTS_URL" ]]; then
        curl -sSL  -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" \
            "$ARTIFACTS_URL"
    fi
  else
    echo "\$GITHUB_TOKEN not defined">&2
  fi
}

function git_list_versions_for_packages () {
  if [[ -n "$1" ]]; then
    if [[ -n $GITHUB_TOKEN ]]; then
      PKG_OWNER="$(echo "$1" | cut -d'/' -f1)"
      PKG_NAME="$(echo "$1" | cut -d':' -f2)"
      for PKG_TAGS in $(curl -sSL  -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" \
                        "https://api.github.com/users/${PKG_OWNER}/packages/container/${PKG_NAME}/versions" \
                        | jq -r '.[] | .metadata.container.tags | .[]' 2>/dev/null | grep -Pv "\-\d{6}\d*$"); do
        echo "ghcr.io/${PKG_OWNER}/${PKG_NAME}:${PKG_TAGS}"
      done
    else
      echo "\$GITHUB_TOKEN not defined">&2
    fi
  else
    echo "package not specified">&2
  fi
}

function git_list_packages_base () {
  WANT_TAGS=${1:-false}
  if [[ -n $GITHUB_TOKEN ]]; then
    for PKG in $(curl -sSL  -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" \
      https://api.github.com/user/packages?package_type=container \
      | jq -r '.[] | .repository.full_name,.name' \
      | sed '$!N;s/\n/:/' \
      | sort -f); do
      [[ "${WANT_TAGS}" == "true" ]] && git_list_versions_for_packages "$PKG" || ( echo "$PKG" | sed "s@:@/@g" )
    done
    if [[ -n $GITHUB_ORGS ]]; then
      for ORG in $(echo "$GITHUB_ORGS" | sed "s/,/ /g"); do \
        for PKG in $(curl -sSL  -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" \
              https://api.github.com/orgs/$ORG/packages?package_type=container \
              | jq -r '.[] | .repository.full_name,.name' \
              | sed '$!N;s/\n/:/' \
              | sort -f); do
          [[ "${WANT_TAGS}" == "true" ]] && git_list_versions_for_packages "$PKG" || ( echo "$PKG" | sed "s@:@/@g" )
        done
      done
    fi
  else
    echo "\$GITHUB_TOKEN not defined">&2
  fi
}

function git_list_packages () {
  git_list_packages_base false
}

function git_list_package_tags () {
  git_list_packages_base true
}

function git_trigger_workflow_dispatch () {
  if [[ -n $GITHUB_TOKEN ]]; then
    REPO="$1"
    WORKFLOW="$2"
    BRANCH="${3:-$(git_default_branch "$REPO")}"
    WORKFLOW_ID="$(git_workflow_id "$REPO" "$WORKFLOW")"
    [[ -z "$WORKFLOW_ID" ]] && WORKFLOW_ID="$WORKFLOW"
    echo "Issuing workflow_dispatch for $WORKFLOW ($WORKFLOW_ID) on $REPO at $BRANCH"
    curl -sSL -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" \
      --data "{\"ref\": \"$BRANCH\"}" \
      "https://api.github.com/repos/$REPO/actions/workflows/$WORKFLOW_ID/dispatches"
  else
    echo "\$GITHUB_TOKEN not defined">&2
  fi
}

function git_trigger_repo_dispatch () {
  if [[ -n $GITHUB_TOKEN ]]; then
    REPO="$1"
    echo "Issuing repository_dispatch on $REPO"
    curl -sSL  -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" \
      --data '{"event_type": "CLI trigger"}' \
      "https://api.github.com/repos/$REPO/dispatches"
  else
    echo "\$GITHUB_TOKEN not defined">&2
  fi
}

function git_trigger_packages_build () {
  if [[ -n $GITHUB_TOKEN ]]; then
    # present the menu to our customer and get their selection
    printf "%s\t%s\n" "0" "ALL"
    readarray -t PACKAGES < <(git_list_packages)
    for i in "${!PACKAGES[@]}"; do
      ((IPLUS=i+1))
      printf "%s\t%s\n" "$IPLUS" "${PACKAGES[$i]}"
    done
    echo -n "Operation:"
    read USER_FUNCTION_IDX

    if (( $USER_FUNCTION_IDX == 0 )); then
      unset CONFIRMATION
      read -p "Are you sure you want to trigger ALL builds? [Y/n]? " CONFIRMATION
      CONFIRMATION=${CONFIRMATION:-Y}
      if [[ $CONFIRMATION =~ ^[Yy] ]]; then
        ALL_REPOS=( "${PACKAGES[@]%:*}" )
        UNIQUE_REPOS=($(echo "${ALL_REPOS[@]}" | tr ' ' '\n' | grep -v '^null$' | sed 's|\(.*\)/.*|\1|' | sort -u | tr '\n' ' '))
        for i in "${!UNIQUE_REPOS[@]}"; do
          git_trigger_repo_dispatch "${UNIQUE_REPOS[$i]}"
        done
      fi

    elif (( $USER_FUNCTION_IDX > 0 )) && (( $USER_FUNCTION_IDX <= "${#PACKAGES[@]}" )); then
      # execute one function, à la carte
      USER_FUNCTION="${PACKAGES[((USER_FUNCTION_IDX-1))]}"
      git_trigger_repo_dispatch "$(echo "$USER_FUNCTION" | cut -d: -f1 | sed 's|\(.*\)/.*|\1|')"

    else
      # some people just want to watch the world burn
      echo "Invalid operation selected">&2
    fi
  else
    echo "\$GITHUB_TOKEN not defined">&2
  fi
}

function github_runner_ubuntu_space_free () {
  if [[ -n $GITHUB_RUN_ID ]] && [[ -n $RUNNER_ENVIRONMENT ]]; then
    sudo docker rmi $(docker image ls -aq) >/dev/null 2>&1 || true
    sudo rm -rf \
      /usr/share/dotnet /usr/local/lib/android /opt/ghc /usr/lib/jvm \
      /usr/local/share/powershell /usr/share/swift /usr/local/.ghcup || true
    sudo env DEBIAN_FRONTEND=noninteractive apt-get -q -y update >/dev/null 2>&1
    sudo env DEBIAN_FRONTEND=noninteractive apt-get -q -y --purge remove \
      azure-cli \
      dotnet* \
      firefox \
      google-chrome-stable \
      google-cloud-cli \
      microsoft-edge-stable \
      mono-* \
      mysql* \
      postgresql* \
      powershell \
      temurin*  >/dev/null 2>&1 || true
    sudo env DEBIAN_FRONTEND=noninteractive apt-get -q -y --purge autoremove >/dev/null 2>&1 || true
  fi
}