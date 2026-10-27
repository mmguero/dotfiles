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
  local GIT_BRANCH=$(current_git_branch)
  if [ ! -z "$GIT_BRANCH" ]; then
    local GIT_REMOTE=$(parse_git_remote_info)
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
    (set -o pipefail && curl "${GITHUB_API_CURL_ARGS[@]}" "https://api.github.com/repos/$1/releases/latest?per_page=500" | jq '.tag_name' | sed -e 's/^"//' -e 's/"$//' ) || \
      (set -o pipefail && curl "${GITHUB_API_CURL_ARGS[@]}" "https://api.github.com/repos/$1/releases?per_page=500" | jq '.[0].tag_name' | sed -e 's/^"//' -e 's/"$//' ) || \
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
    (set -o pipefail && curl "${GITHUB_API_CURL_ARGS[@]}" "https://api.github.com/repos/$1/releases?per_page=500" | jq 'reverse | [.[] | select(.assets | length > 0) | { tag_name: .tag_name, assets: [.assets[] | select(.download_count > 0) | { name: .name, download_count: .download_count }] }]' ) || \
      echo unknown
  else
    echo unknown>&2
  fi
}

function git_deep_search () {
  if [ "$1" ]; then
    PATTERN="$1"
    (
      set -o pipefail && { find .git/objects/pack/ -name "*.idx" | while read i; do git show-index < "$i" | awk '{print $2}'; done; find .git/objects/ -type f | grep -v '/pack/' | awk -F'/' '{print $(NF-1)$NF}'; } | while read o; do git cat-file -p $o; done | grep -E "$PATTERN"
    )
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

function git_list_repos () {
  WANT_TAGS=${1:-false}
  if [[ -n $GITHUB_TOKEN ]]; then
    for REPO in $(curl -sSL  -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" \
      "https://api.github.com/user/repos?per_page=500" \
      | jq -r '.[] | .full_name' \
      | sort -f); do
      echo "$REPO"
    done
  else
    echo "\$GITHUB_TOKEN not defined">&2
  fi
}

################################################################################
# git_install_tool - generalized GitHub binary installer
# Usage:
#   git_install_tool <repo> <binary_name> <asset_pattern_amd64> <asset_pattern_arm64> [--strip N]
#
# Examples:
#   git_install_tool schollz/croc croc \
#     "croc_{ver}_Linux-64bit.tar.gz" "croc_{ver}_Linux-ARM64.tar.gz" --strip 0
#
#   git_install_tool mikefarah/yq yq \
#     "yq_linux_amd64" "yq_linux_arm64"
################################################################################
function git_install_tool {
  local repo="$1"
  local bin_name="$2"
  local amd64_pattern="$3"
  local arm64_pattern="$4"
  local strip_components=1

  shift 4
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --strip) strip_components="$2"; shift ;;
    esac
    shift
  done

  local release="$(git_latest_release "$repo")"
  local dest_dir="$HOME"/.local/bin
  mkdir -p "$dest_dir"
  local tmp_dir="$(mktemp -d)"

  local linux_cpu="$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')"
  local arch_pattern=""
  case "$linux_cpu" in
    amd64) arch_pattern="$amd64_pattern" ;;
    arm64) arch_pattern="$arm64_pattern" ;;
    *) echo "Unsupported architecture: $linux_cpu" >&2; return 1 ;;
  esac

  arch_pattern="${arch_pattern//\{ver\}/$release}"
  local url="https://github.com/${repo}/releases/download/${release}/${arch_pattern}"

  # Default binary name = repo basename if omitted or '-'
  if [[ -z "$bin_name" || "$bin_name" == "-" ]]; then
    bin_name="$(basename "$repo")"
  fi

  echo "Installing $bin_name from $url" >&2

  local is_tarball=false
  [[ "$arch_pattern" =~ \.tar\.gz$|\.tgz$ ]] && is_tarball=true

  if $is_tarball; then
    if [[ "$strip_components" -eq 0 ]]; then
      curl -sSL "$url" | tar xzf - -C "$tmp_dir"
    else
      curl -sSL "$url" | tar xzf - --strip-components "$strip_components" -C "$tmp_dir"
    fi

    # Try to locate binary
    local found_bin
    found_bin="$(find "$tmp_dir" -type f -name "$bin_name" -perm -111 -print -quit)"
    if [[ -z "$found_bin" ]]; then
      found_bin="$(find "$tmp_dir" -type f -perm -111 -print -quit)"
    fi
    if [[ -z "$found_bin" ]]; then
      echo "Error: could not detect binary in tarball" >&2
      rm -rf "$tmp_dir"
      return 1
    fi

    cp -f "$found_bin" "$dest_dir/$bin_name"
  else
    curl -sSL -o "$dest_dir/$bin_name" "$url"
  fi

  chmod 755 "$dest_dir/$bin_name"
  rm -rf "$tmp_dir"
}


function git_list_workflows () {
  if [[ -n $GITHUB_TOKEN ]]; then
    REPO="$1"
    curl -sSL  -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" \
      "https://api.github.com/repos/$REPO/actions/workflows?per_page=500" \
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
    [[ $WORKFLOW == ?(-)+([0-9]) ]] || WORKFLOW=$(git_workflow_id "$REPO" "$WORKFLOW")
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
      "https://api.github.com/repos/$REPO/actions/workflows/$WORKFLOW/runs?per_page=500"
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
      "https://api.github.com/user/packages?package_type=container&per_page=500" \
      | jq -r '.[] | .repository.full_name,.name' \
      | sed '$!N;s/\n/:/' \
      | sort -f); do
      [[ "${WANT_TAGS}" == "true" ]] && git_list_versions_for_packages "$PKG" || ( echo "$PKG" | sed "s@:@/@g" )
    done
    if [[ -n $GITHUB_ORGS ]]; then
      for ORG in $(echo "$GITHUB_ORGS" | sed "s/,/ /g"); do \
        for PKG in $(curl -sSL  -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" \
              "https://api.github.com/orgs/$ORG/packages?package_type=container&per_page=500" \
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

function github_malcolm_release_stats () {
  RELEASE_IDX=${1:--1}
  FORK_1=${2:-idaholab/Malcolm}
  FORK_2=${3:-cisagov/Malcolm}
  jq -s '
    map(.assets) | add |
    group_by(.name) |
    map({
      name: .[0].name,
      download_count: map(.download_count) | add
    })
  ' <( git_release_download_counts "${FORK_1}" | jq ".[${RELEASE_IDX}]" ) \
     <( git_release_download_counts "${FORK_2}" | jq ".[${RELEASE_IDX}]" )
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

function github_issue_comments () {
  if [[ -n "$1" ]]; then
    local ISSUE_REF="$1"
    local REPO="${ISSUE_REF%%#*}"
    local NUM="${ISSUE_REF##*#}"
    if [[ -z "$REPO" || -z "$NUM" || "$REPO" == "$ISSUE_REF" ]]; then
      echo "Usage: github_issue_comments owner/repo#123">&2
      return 1
    fi
    GITHUB_API_CURL_ARGS=()
    GITHUB_API_CURL_ARGS+=( -fsSL )
    GITHUB_API_CURL_ARGS+=( -H )
    GITHUB_API_CURL_ARGS+=( "Accept: application/vnd.github.v3+json" )
    [[ -n "$GITHUB_TOKEN" ]] && \
      GITHUB_API_CURL_ARGS+=( -H ) && \
      GITHUB_API_CURL_ARGS+=( "Authorization: token $GITHUB_TOKEN" )

    curl "${GITHUB_API_CURL_ARGS[@]}" "https://api.github.com/repos/$REPO/issues/$NUM/comments?per_page=500" \
      | jq -r '
          if length == 0 then "(no comments)" else
            .[] | "── \(.user.login)  ·  \(.created_at) ──", "", (.body // ""), ""
          end
        '
  else
    echo "No issue specified, e.g. github_issue_comments cisagov/Malcolm#123">&2
  fi
}

function github_issue () {
  if [[ -z "$1" ]]; then
    echo "No issue specified, e.g. github_issue cisagov/Malcolm#123 [-c] [-p]">&2
    return 1
  fi

  local ISSUE_REF="$1"
  shift
  local REPO="${ISSUE_REF%%#*}"
  local NUM="${ISSUE_REF##*#}"
  if [[ -z "$REPO" || -z "$NUM" || "$REPO" == "$ISSUE_REF" ]]; then
    echo "Usage: github_issue owner/repo#123 [-c] [-p]">&2
    return 1
  fi

  local SHOW_COMMENTS= SHOW_PATCH= OPT
  for OPT in "$@"; do
    case "$OPT" in
      -c) SHOW_COMMENTS=1 ;;
      -p) SHOW_PATCH=1 ;;
      -cp|-pc) SHOW_COMMENTS=1; SHOW_PATCH=1 ;;
      *)
        echo "Unknown option: $OPT" >&2
        echo "Usage: github_issue owner/repo#123 [-c] [-p]">&2
        return 1
        ;;
    esac
  done

  local -a AUTH_ARGS=()
  [[ -n "$GITHUB_TOKEN" ]] && AUTH_ARGS=( -H "Authorization: token $GITHUB_TOKEN" )

  local ISSUE_JSON
  ISSUE_JSON="$(curl -fsSL -H "Accept: application/vnd.github.v3+json" "${AUTH_ARGS[@]}" \
    "https://api.github.com/repos/$REPO/issues/$NUM")" || return 1

  jq -r '
      "#\(.number)  \(.title)",
      "\(.state | ascii_upcase)  ·  \(.user.login)  ·  \(.created_at)",
      (if (.labels | length) > 0 then "Labels: " + ([.labels[].name] | join(", ")) else empty end),
      (if .pull_request then "[this is a pull request]" else empty end),
      "",
      (.body // "(no description)"),
      "",
      .html_url
    ' <<< "$ISSUE_JSON"

  if [[ -n "$SHOW_PATCH" ]]; then
    if jq -e '.pull_request' <<< "$ISSUE_JSON" >/dev/null; then
      local PATCH
      PATCH="$(curl -fsSL -H "Accept: application/vnd.github.v3.diff" "${AUTH_ARGS[@]}" \
        "https://api.github.com/repos/$REPO/pulls/$NUM")" || return 1

      # make the fence longer than any backtick run inside the patch
      local LONGEST FENCE_LEN FENCE
      LONGEST=$(grep -o '`\+' <<< "$PATCH" | awk '{ if (length > m) m = length } END { print m+0 }')
      FENCE_LEN=$(( LONGEST >= 3 ? LONGEST + 1 : 3 ))
      FENCE="$(printf '%*s' "$FENCE_LEN" '' | tr ' ' '`')"

      echo ""
      echo "── patch ──"
      echo ""
      echo "${FENCE}diff"
      printf '%s\n' "$PATCH"
      echo "$FENCE"
    else
      echo "" >&2
      echo "(-p ignored: #$NUM is not a pull request)" >&2
    fi
  fi

  if [[ -n "$SHOW_COMMENTS" ]]; then
    echo ""
    echo "── comments ──"
    echo ""
    github_issue_comments "$ISSUE_REF"
  fi
}

function github_milestone_number () {
  if [[ -n "$1" ]] && [[ -n "$2" ]]; then
    local REPO="$1"
    local MILESTONE="$2"
    GITHUB_API_CURL_ARGS=()
    GITHUB_API_CURL_ARGS+=( -fsSL )
    GITHUB_API_CURL_ARGS+=( -H )
    GITHUB_API_CURL_ARGS+=( "Accept: application/vnd.github.v3+json" )
    [[ -n "$GITHUB_TOKEN" ]] && \
      GITHUB_API_CURL_ARGS+=( -H ) && \
      GITHUB_API_CURL_ARGS+=( "Authorization: token $GITHUB_TOKEN" )

    curl "${GITHUB_API_CURL_ARGS[@]}" "https://api.github.com/repos/$REPO/milestones?state=all&per_page=500" \
      | jq -r --arg m "$MILESTONE" '.[] | select(.title == $m) | .number'
  else
    echo "Usage: github_milestone_number owner/repo milestone-title">&2
  fi
}

function github_milestone_issues () {
  if [[ -n "$1" ]] && [[ -n "$2" ]]; then
    local REPO="$1"
    local MILESTONE="$2"
    local NUM
    NUM="$(github_milestone_number "$REPO" "$MILESTONE")"
    if [[ -z "$NUM" ]]; then
      echo "No milestone named '$MILESTONE' found in $REPO">&2
      return 1
    fi

    GITHUB_API_CURL_ARGS=()
    GITHUB_API_CURL_ARGS+=( -fsSL )
    GITHUB_API_CURL_ARGS+=( -H )
    GITHUB_API_CURL_ARGS+=( "Accept: application/vnd.github.v3+json" )
    [[ -n "$GITHUB_TOKEN" ]] && \
      GITHUB_API_CURL_ARGS+=( -H ) && \
      GITHUB_API_CURL_ARGS+=( "Authorization: token $GITHUB_TOKEN" )

    curl "${GITHUB_API_CURL_ARGS[@]}" "https://api.github.com/repos/$REPO/issues?milestone=$NUM&state=all&per_page=500" \
      | jq -r '
          sort_by(.pull_request != null, .number) | .[] |
          "\(if .pull_request then "PR " else "#  " end)\(.number)\t\(.state)\t\(.title)"
        ' \
      | column -t -s $'\t'
  else
    echo "Usage: github_milestone_issues owner/repo milestone-title">&2
  fi
}

function github_advisory () {
  if [[ -z "$1" ]]; then
    echo "No advisory specified, e.g. github_advisory GHSA-qv8w-m37v-6c7j [-c]">&2
    echo "       github_advisory cisagov/Malcolm#GHSA-qv8w-m37v-6c7j [-c]">&2
    echo "       github_advisory https://github.com/cisagov/Malcolm/security/advisories/GHSA-qv8w-m37v-6c7j [-c]">&2
    return 1
  fi

  local ADV_REF="$1"
  shift
  local REPO= GHSA_ID=

  if [[ "$ADV_REF" =~ ^https?:// ]]; then
    REPO="$(echo "$ADV_REF" | sed -E 's#https?://github\.com/([^/]+/[^/]+)/security/advisories.*#\1#')"
    GHSA_ID="$(echo "$ADV_REF" | grep -oE 'GHSA-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}')"
  elif [[ "$ADV_REF" == *#* ]]; then
    REPO="${ADV_REF%%#*}"
    GHSA_ID="${ADV_REF##*#}"
  else
    GHSA_ID="$ADV_REF"
  fi

  if [[ -z "$GHSA_ID" ]]; then
    echo "Could not parse a GHSA id out of '$ADV_REF'">&2
    return 1
  fi

  local SHOW_COMMENTS= OPT
  for OPT in "$@"; do
    case "$OPT" in
      -c) SHOW_COMMENTS=1 ;;
      *)
        echo "Unknown option: $OPT">&2
        echo "Usage: github_advisory GHSA-id|owner/repo#GHSA-id|URL [-c]">&2
        return 1
        ;;
    esac
  done

  local -a AUTH_ARGS=()
  [[ -n "$GITHUB_TOKEN" ]] && AUTH_ARGS=( -H "Authorization: token $GITHUB_TOKEN" )

  # Prefer the repo-scoped endpoint when we know the repo — it's required for
  # private/unpublished advisories and it's the only one with a comment thread.
  # Fall back to the global advisories endpoint (public advisories only, no repo needed).
  local ADVISORY_JSON=
  if [[ -n "$REPO" ]]; then
    ADVISORY_JSON="$(curl -fsSL -H "Accept: application/vnd.github.v3+json" "${AUTH_ARGS[@]}" \
      "https://api.github.com/repos/$REPO/security-advisories/$GHSA_ID" 2>/dev/null)"
  fi
  if [[ -z "$ADVISORY_JSON" ]]; then
    ADVISORY_JSON="$(curl -fsSL -H "Accept: application/vnd.github.v3+json" "${AUTH_ARGS[@]}" \
      "https://api.github.com/advisories/$GHSA_ID" 2>/dev/null)"
  fi

  if [[ -z "$ADVISORY_JSON" ]]; then
    echo "Could not retrieve advisory $GHSA_ID${REPO:+ for $REPO}">&2
    return 1
  fi

  jq -r '
      "\(.ghsa_id // "unknown")  ·  \((.severity // "unknown") | ascii_upcase)  ·  \(.cve_id // "no CVE")",
      "\((.state // "") | ascii_upcase)  ·  published \(.published_at // "unpublished")  ·  updated \(.updated_at // "")",
      (if .withdrawn_at then "WITHDRAWN: \(.withdrawn_at)" else empty end),
      (if (.summary // "") != "" then ("", .summary) else empty end),
      "",
      (.description // "(no description)"),
      (if (.cvss.score // null) != null then ("", "CVSS: \(.cvss.score) (\(.cvss.vector_string // "n/a"))") else empty end),
      (if ((.cwes // []) | length) > 0 then "CWEs: " + ([.cwes[].cwe_id] | join(", ")) else empty end),
      (if ((.vulnerabilities // []) | length) > 0 then ("", "Affected packages:") else empty end),
      (.vulnerabilities[]? | "  - \(.package.ecosystem // "")/\(.package.name // "") \(.vulnerable_version_range // "")" + (if .first_patched_version.identifier then " (patched in \(.first_patched_version.identifier))" else "" end)),
      (if ((.credits // []) | length) > 0 then ("", "Credits: " + ([.credits[]?.user.login] | join(", "))) else empty end),
      (if ((.references // []) | length) > 0 then ("", "References:", (.references[] | "  - \(.)")) else empty end),
      "",
      (.html_url // .url // "")
    ' <<< "$ADVISORY_JSON"

  if [[ -n "$SHOW_COMMENTS" ]]; then
    echo ""
    echo "── comments ──"
    echo ""
    if [[ -n "$REPO" ]]; then
      local COMMENTS_JSON
      COMMENTS_JSON="$(curl -fsSL -H "Accept: application/vnd.github.v3+json" "${AUTH_ARGS[@]}" \
        "https://api.github.com/repos/$REPO/security-advisories/$GHSA_ID/comments?per_page=500" 2>/dev/null)"
      if [[ -n "$COMMENTS_JSON" ]] && jq -e 'type == "array"' <<< "$COMMENTS_JSON" >/dev/null 2>&1; then
        jq -r '
            if length == 0 then "(no comments)" else
              .[] | "── \(.user.login)  ·  \(.created_at) ──", "", (.body // ""), ""
            end
          ' <<< "$COMMENTS_JSON"
      else
        echo "(no comments found, or this advisory has no accessible comment thread)"
      fi
    else
      echo "(no repo context for $GHSA_ID, can't check for a comment thread)"
    fi
  fi
}
