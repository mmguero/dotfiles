#!/usr/bin/env bash
#
# install-user-local-binaries.sh
#
# Download user-local binaries from GitHub releases via fetch.
#
# The caller must export _DownloadViaFetch:
#   export -f _DownloadViaFetch
#
# Environment (all optional):
#   LOCAL_BIN_PATH   where binaries land        (default: ~/.local/bin)
#   LOCAL_DATA_PATH  where completions land     (default: ~/.local/share)
#   LINUX_CPU        CPU name as from uname -m  (default: $(uname -m))
#   FETCH            path to the fetch binary   (default: $LOCAL_BIN_PATH/fetch)
#   DL_TMP_PATH      parent of the per-run staging directory (default: $TMPDIR or /tmp)
#   GITHUB_OAUTH_TOKEN or GITHUB_TOKEN
#                    sent with dry-run API calls, to avoid the 60 requests/hour
#                    limit for anonymous callers (fetch reads the same variable)

set -o nounset
set -o pipefail

usage() {
  cat <<EOF
usage: $(basename "$0") [-y] [-l] [-n [-a]] [TOOL ...]

  -y      download everything without prompting
  -l      list tools available for this architecture and exit
  -n      dry run: check each asset resolves the way fetch would, download nothing
  -a      with -n, check every architecture column instead of just this one
  TOOL    only download (or check) these tools, no prompting
EOF
}

LOCAL_BIN_PATH="${LOCAL_BIN_PATH:-$HOME/.local/bin}"
LOCAL_DATA_PATH="${LOCAL_DATA_PATH:-$HOME/.local/share}"
LINUX_CPU="${LINUX_CPU:-$(uname -m)}"
FETCH="${FETCH:-$LOCAL_BIN_PATH/fetch}"
DL_TMP_PATH="${DL_TMP_PATH:-${TMPDIR:-/tmp}}"

ASSUME_YES=false
LIST_ONLY=false
DRY_RUN=false
ALL_ARCHES=false
while getopts ':ylnah' opt; do
  case "$opt" in
    y) ASSUME_YES=true ;;
    l) LIST_ONLY=true ;;
    n) DRY_RUN=true ;;
    a) ALL_ARCHES=true ;;
    h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))

declare -A WANTED=()
for name in "$@"; do WANTED[$name]=1; done

case "$LINUX_CPU" in
  x86_64|amd64)  ARCH=amd64 ;;
  aarch64|arm64) ARCH=arm64 ;;
  armv6*)        ARCH=armv6 ;;
  arm*)          ARCH=armv7 ;;
  *) echo "Unsupported CPU: $LINUX_CPU" >&2; exit 1 ;;
esac
declare -A ARCH_COLUMN=([amd64]=4 [arm64]=5 [armv7]=6 [armv6]=7)
if $ALL_ARCHES && $DRY_RUN; then
  CHECK_ARCHES=(amd64 arm64 armv7 armv6)
else
  CHECK_ARCHES=("$ARCH")
fi

# Stage downloads in a private per-run directory. Exporting it as TMPDIR puts the
# mktemp calls in _DownloadViaFetch (and fetch's own temp files) under it too,
# so this one trap cleans up after Ctrl-C or a failed download.
if ! $DRY_RUN && ! $LIST_ONLY; then
  DL_TMP_PATH="$(mktemp -d "$DL_TMP_PATH/user-local-bin.XXXXXX")" || exit 1
  export TMPDIR="$DL_TMP_PATH"
  trap 'rm -rf "$DL_TMP_PATH"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
fi

# Prompts read from the terminal so they never eat the asset table or piped input.
_Confirm() {
  local prompt="$1" default="$2" reply=""
  $ASSUME_YES && return 0
  read -r -p "$prompt " reply </dev/tty || true
  [[ ${reply:-$default} =~ ^[Yy] ]]
}

# One row per tool. Columns are whitespace separated:
#   name  owner/repo  destination  mode  amd64  arm64  armv7  armv6
# @BIN expands to $LOCAL_BIN_PATH, @TMP to $DL_TMP_PATH.
# A "-" in an architecture column means no build for that architecture.
# A "-" in the mode column means the asset is an archive for _DownloadViaFetch to unpack.
mapfile -t ROWS < <(grep -Ev '^[[:space:]]*(#|$)' <<'EOF'
age                              FiloSottile/age                @TMP/age.tar.gz         -    ^age-v.+-linux-amd64\.tar\.gz$                         ^age-v.+-linux-arm64\.tar\.gz$                          ^age-v.+-linux-arm\.tar\.gz$                          ^age-v.+-linux-arm\.tar\.gz$
act                              nektos/act                     @TMP/act.tar.gz         -    ^act_Linux_x86_64\.tar\.gz$                            ^act_Linux_arm64\.tar\.gz$                              ^act_Linux_armv7\.tar\.gz$                            ^act_Linux_armv6\.tar\.gz$
as-tree                          jez/as-tree                    @TMP/as-tree.zip        -    ^as-tree-.+-linux\.zip$                                -                                                       -                                                     -
bat                              sharkdp/bat                    @TMP/bat.tar.gz         -    ^bat-v.+-x86_64-unknown-linux-gnu\.tar\.gz$            ^bat-v.+-aarch64-unknown-linux-gnu\.tar\.gz$            ^bat-v.+-arm-unknown-linux-musleabihf\.tar\.gz$       ^bat-v.+-arm-unknown-linux-musleabihf\.tar\.gz$
bluetuith                        darkhz/bluetuith               @TMP/bluetuith.tar.gz   -    ^bluetuith_.+_Linux_x86_64\.tar\.gz$                   ^bluetuith_.+_Linux_arm64\.tar\.gz$                     ^bluetuith_.+_Linux_armv7\.tar\.gz$                   ^bluetuith_.+_Linux_armv6\.tar\.gz$
boringproxy                      boringproxy/boringproxy        @BIN/boringproxy        755  ^boringproxy-linux-x86_64$                             ^boringproxy-linux-arm64$                               ^boringproxy-linux-arm$                               ^boringproxy-linux-arm$
croc                             schollz/croc                   @TMP/croc.tar.gz        -    ^croc_.+_Linux-64bit\.tar\.gz$                         ^croc_.+_Linux-ARM64\.tar\.gz$                          ^croc_.+_Linux-ARM\.tar\.gz$                          ^croc_.+_Linux-ARM\.tar\.gz$
difft                            Wilfred/difftastic             @TMP/difft.tar.gz       -    ^difft-.+-x86_64-unknown-linux-gnu\.tar\.gz$           ^difft-.+-aarch64-unknown-linux-gnu\.tar\.gz$           -                                                     -
diffoci                          reproducible-containers/diffoci @BIN/diffoci           755  ^diffoci-v.+\.linux-amd64$                             ^diffoci-v.+\.linux-arm64$                              ^diffoci-v.+\.linux-arm-v7$                           -
docker-credential-pass           docker/docker-credential-helpers @BIN/docker-credential-pass 755 ^docker-credential-pass-v.+\.linux-amd64$     ^docker-credential-pass-v.+\.linux-arm64$               ^docker-credential-pass-v.+\.linux-armv7$             ^docker-credential-pass-v.+\.linux-armv6$
docker-credential-secretservice  docker/docker-credential-helpers @BIN/docker-credential-secretservice 755 ^docker-credential-secretservice-v.+\.linux-amd64$ ^docker-credential-secretservice-v.+\.linux-arm64$ ^docker-credential-secretservice-v.+\.linux-armv7$ ^docker-credential-secretservice-v.+\.linux-armv6$
eza                              eza-community/eza              @TMP/eza.tar.gz         -    ^eza_x86_64-unknown-linux-musl\.tar\.gz$               ^eza_aarch64-unknown-linux-gnu\.tar\.gz$                ^eza_arm-unknown-linux-gnueabihf\.tar\.gz$            ^eza_arm-unknown-linux-gnueabihf\.tar\.gz$
fd                               sharkdp/fd                     @TMP/fd.tar.gz          -    ^fd-v.+-x86_64-unknown-linux-gnu\.tar\.gz$             ^fd-v.+-aarch64-unknown-linux-gnu\.tar\.gz$             ^fd-v.+-arm-unknown-linux-musleabihf\.tar\.gz$        ^fd-v.+-arm-unknown-linux-musleabihf\.tar\.gz$
ffsend                           timvisee/ffsend                @BIN/ffsend             755  ^ffsend-v.+-linux-x64-static$                          -                                                       -                                                     -
fflo.com                         nuwainfo/ffl                   @BIN/fflo.com           644  ^fflo\.com$                                            ^fflo\.com$                                             -                                                     -
flightsim                        alphasoc/flightsim             @TMP/flightsim.tar.gz   -    ^flightsim_.+_linux_amd64\.tar\.gz$                    -                                                       -                                                     -
fq                               wader/fq                       @TMP/fq.tar.gz          -    ^fq_.+_linux_amd64\.tar\.gz$                           ^fq_.+_linux_arm64\.tar\.gz$                            -                                                     -
fx                               antonmedv/fx                   @BIN/fx                 755  ^fx_linux_amd64$                                       ^fx_linux_arm64$                                        -                                                     -
ghorg                            gabrie30/ghorg                 @TMP/ghorg.tar.gz       -    ^ghorg_.+_Linux_x86_64\.tar\.gz$                       ^ghorg_.+_Linux_arm64\.tar\.gz$                         -                                                     -
gron                             tomnomnom/gron                 @TMP/gron.tgz           -    ^gron-linux-amd64-.+\.tgz$                             ^gron-linux-arm64-.+\.tgz$                              -                                                     -
hostyoself                       schollz/hostyoself             @TMP/hostyoself.tar.gz  -    ^hostyoself_.+_Linux-64bit\.tar\.gz$                   ^hostyoself_.+_Linux-ARM64\.tar\.gz$                    ^hostyoself_.+_Linux-ARM\.tar\.gz$                    ^hostyoself_.+_Linux-ARM\.tar\.gz$
httpx                            projectdiscovery/httpx         @TMP/httpx.zip          -    ^httpx_.+_linux_amd64\.zip$                            ^httpx_.+_linux_arm64\.zip$                             ^httpx_.+_linux_arm\.zip$                             ^httpx_.+_linux_arm\.zip$
jd                               josephburnett/jd               @BIN/jd                 755  ^jd-amd64-linux$                                       ^jd-arm64-linux$                                        -                                                     -
k9s                              derailed/k9s                   @TMP/k9s.tar.gz         -    ^k9s_Linux_amd64\.tar\.gz$                             ^k9s_Linux_arm64\.tar\.gz$                              ^k9s_Linux_armv7\.tar\.gz$                            -
kubeconform                      yannh/kubeconform              @TMP/kubeconform.tar.gz -    ^kubeconform-linux-amd64\.tar\.gz$                     ^kubeconform-linux-arm64\.tar\.gz$                      ^kubeconform-linux-armv6\.tar\.gz$                    ^kubeconform-linux-armv6\.tar\.gz$
minikube                         kubernetes/minikube            @BIN/minikube           755  ^minikube-linux-amd64$                                 ^minikube-linux-arm64$                                  -                                                     -
peco                             peco/peco                      @TMP/peco.tar.gz        -    ^peco_.+_linux_amd64\.tar\.gz$                         ^peco_.+_linux_arm64\.tar\.gz$                          ^peco_.+_linux_armv6\.tar\.gz$                        ^peco_.+_linux_armv6\.tar\.gz$
pik                              programmersd21/pik             @BIN/pik                755  ^pik-linux-x86_64$                                     -                                                       -                                                     -
rclone                           rclone/rclone                  @TMP/rclone.zip         -    ^rclone-v.+-linux-amd64\.zip$                          ^rclone-v.+-linux-arm64\.zip$                           ^rclone-v.+-linux-arm-v7\.zip$                        ^rclone-v.+-linux-arm\.zip$
rclone-tui                       darkhz/rclone-tui              @TMP/rclone-tui.tar.gz  -    ^rclone-tui_.+_Linux_x86_64\.tar\.gz$                  ^rclone-tui_.+_Linux_arm64\.tar\.gz$                    ^rclone-tui_.+_Linux_armv7\.tar\.gz$                  ^rclone-tui_.+_Linux_armv6\.tar\.gz$
ripgrep                          BurntSushi/ripgrep             @TMP/ripgrep.tar.gz     -    ^ripgrep-.+-x86_64-unknown-linux-musl\.tar\.gz$        ^ripgrep-.+-aarch64-unknown-linux-musl\.tar\.gz$        ^ripgrep-.+-armv7-unknown-linux-musleabihf\.tar\.gz$  -
sq                               neilotoole/sq                  @TMP/sq.tar.gz          -    ^sq.+linux-amd64\.tar\.gz$                             ^sq.+linux-arm64\.tar\.gz$                              -                                                     -
starship                         starship/starship              @TMP/starship.tar.gz    -    ^starship-x86_64-unknown-linux-gnu\.tar\.gz$           ^starship-aarch64-unknown-linux-musl\.tar\.gz$          ^starship-arm-unknown-linux-musleabihf\.tar\.gz$      ^starship-arm-unknown-linux-musleabihf\.tar\.gz$
step                             smallstep/cli                  @TMP/step.tar.gz        -    ^step_linux_.+_amd64\.tar\.gz$                         ^step_linux_.+_arm64\.tar\.gz$                          ^step_linux_.+_armv7\.tar\.gz$                        ^step_linux_.+_armv6\.tar\.gz$
stern                            stern/stern                    @TMP/stern.tar.gz       -    ^stern_.+_linux_amd64\.tar\.gz$                        ^stern_.+_linux_arm64\.tar\.gz$                         ^stern_.+_linux_arm\.tar\.gz$                         -
supercronic                      aptible/supercronic            @BIN/supercronic        755  ^supercronic-linux-amd64$                              ^supercronic-linux-arm64$                               ^supercronic-linux-arm$                               ^supercronic-linux-arm$
termshark                        gcla/termshark                 @TMP/termshark.tar.gz   -    ^termshark_.+_linux_x64\.tar\.gz$                      ^termshark_.+_linux_arm64\.tar\.gz$                     ^termshark_.+_linux_armv6\.tar\.gz$                   ^termshark_.+_linux_armv6\.tar\.gz$
viddy                            sachaos/viddy                  @TMP/viddy.tar.gz       -    ^viddy-.+-linux-x86_64\.tar\.gz$                       ^viddy-.+-linux-arm64\.tar\.gz$                         -                                                     -
watchexec                        watchexec/watchexec            @TMP/watchexec.tar.xz   -    ^watchexec-.+-x86_64-unknown-linux-musl\.tar\.xz$      ^watchexec-.+-aarch64-unknown-linux-musl\.tar\.xz$      ^watchexec-.+-armv7-unknown-linux-gnueabihf\.tar\.xz$ -
wireproxy                        whyvl/wireproxy                @TMP/wireproxy.tar.gz   -    ^wireproxy_linux_amd64\.tar\.gz$                       ^wireproxy_linux_arm64\.tar\.gz$                        ^wireproxy_linux_arm\.tar\.gz$                        ^wireproxy_linux_arm\.tar\.gz$
yq                               mikefarah/yq                   @BIN/yq                 755  ^yq_linux_amd64$                                       ^yq_linux_arm64$                                        ^yq_linux_arm$                                        ^yq_linux_arm$
zoxide                           ajeetdsouza/zoxide             @TMP/zoxide.tar.gz      -    ^zoxide-.+-x86_64-unknown-linux-musl\.tar\.gz$         ^zoxide-.+-aarch64-unknown-linux-musl\.tar\.gz$         ^zoxide-.+-armv7-unknown-linux-musleabihf\.tar\.gz$   ^zoxide-.+-arm-unknown-linux-musleabihf\.tar\.gz$
EOF
)

# Turn the table into the "url|pattern|dest[|mode]" specs _DownloadViaFetch expects,
# keeping only rows that have a build for this architecture (and were asked for).
NAMES=()
SPECS=()
SPEC_ARCHES=()
for row in "${ROWS[@]}"; do
  read -r -a f <<<"$row"
  name="${f[0]}" repo="${f[1]}" dest="${f[2]}" mode="${f[3]}"
  (( ${#WANTED[@]} )) && [[ -z "${WANTED[$name]:-}" ]] && continue
  dest="${dest/#@BIN/$LOCAL_BIN_PATH}"
  dest="${dest/#@TMP/$DL_TMP_PATH}"
  for arch in "${CHECK_ARCHES[@]}"; do
    pattern="${f[${ARCH_COLUMN[$arch]}]:--}"
    [[ "$pattern" == "-" ]] && continue
    spec="https://github.com/$repo|$pattern|$dest"
    [[ "$mode" != "-" ]] && spec+="|$mode"
    NAMES+=("$name")
    SPECS+=("$spec")
    SPEC_ARCHES+=("$arch")
  done
done

if $LIST_ONLY; then
  printf '%s\n' "${NAMES[@]}"
  exit 0
fi

for name in "${!WANTED[@]}"; do
  [[ " ${NAMES[*]} " == *" $name "* ]] || echo "No $ARCH build listed for: $name" >&2
done
(( ${#SPECS[@]} )) || exit 0

# ---- dry run -------------------------------------------------------------

# _DownloadViaFetch calls fetch with --tag=">=0.0.0", so fetch takes the highest
# semver tag in the repo (prereleases excluded), then downloads from the release
# on that tag. That isn't always the release GitHub marks "latest", so the dry run
# resolves the tag the same way: git ls-remote for tags, then the release for it.
# Results are cached per repo, since two tools share docker-credential-helpers.
declare -A RELEASE_ASSETS=()
declare -A RELEASE_TAG=()
declare -A RELEASE_ERROR=()

_HighestSemverTag() {
  GIT_TERMINAL_PROMPT=0 git ls-remote --tags --refs "https://github.com/$1" 2>/dev/null | \
    sed 's#.*refs/tags/##' | \
    grep -E '^v?[0-9]+(\.[0-9]+)*(\+.*)?$' | \
    awk '{ v = $0; sub(/^v/, "", v); sub(/\+.*/, "", v); print v "\t" $0 }' | \
    sort -t $'\t' -k1,1V | tail -n 1 | cut -f2
}

_LoadRelease() {
  local repo="$1" tag response code
  [[ -n "${RELEASE_ASSETS[$repo]+x}" ]] && return 0
  RELEASE_ASSETS[$repo]=""

  tag="$(_HighestSemverTag "$repo")"
  if [[ -z "$tag" ]]; then
    RELEASE_ERROR[$repo]="no semver tags found (repo missing, or tags not semver)"
    return 0
  fi
  RELEASE_TAG[$repo]="$tag"

  local token="${GITHUB_OAUTH_TOKEN:-${GITHUB_TOKEN:-}}"
  local -a auth=()
  [[ -n "$token" ]] && auth=(-H "Authorization: Bearer $token")
  response="$(curl -sSL -w '\n%{http_code}' \
                -H 'Accept: application/vnd.github+json' ${auth[@]+"${auth[@]}"} \
                "https://api.github.com/repos/$repo/releases/tags/$tag" 2>&1)"
  code="${response##*$'\n'}"
  case "$code" in
    200) RELEASE_ASSETS[$repo]="$(grep -o '"browser_download_url": *"[^"]*"' <<<"$response" | \
                                  sed 's/.*"\(https\?:[^"]*\)"$/\1/')" ;;
    403|429) RELEASE_ERROR[$repo]="API rate limited (HTTP $code); set GITHUB_OAUTH_TOKEN" ;;
    404) RELEASE_ERROR[$repo]="highest tag $tag has no GitHub release, so fetch will fail" ;;
    *)   RELEASE_ERROR[$repo]="API request failed (HTTP ${code:-none})" ;;
  esac
}

# Returns 0 if exactly one asset in the latest release matches and it downloads.
_CheckSpec() {
  local name="$1" arch="$2" spec="$3"
  local url pattern repo asset code
  IFS='|' read -r url pattern _ <<<"$spec"
  repo="${url#https://github.com/}"

  _LoadRelease "$repo"
  if [[ -n "${RELEASE_ERROR[$repo]:-}" ]]; then
    printf 'ERROR    %-6s %-32s %s\n' "$arch" "$name" "${RELEASE_ERROR[$repo]}"
    return 1
  fi

  local -a matches=()
  while IFS= read -r asset; do
    [[ -n "$asset" && "${asset##*/}" =~ $pattern ]] && matches+=("$asset")
  done <<<"${RELEASE_ASSETS[$repo]}"

  if (( ${#matches[@]} == 0 )); then
    printf 'MISSING  %-6s %-32s nothing in %s matches %s\n' "$arch" "$name" "${RELEASE_TAG[$repo]}" "$pattern"
    return 1
  fi

  # Ask for one byte so we test the real download without pulling the file.
  code="$(curl -sL -r 0-0 -o /dev/null -w '%{http_code}' "${matches[0]}")"
  if [[ "$code" != "200" && "$code" != "206" ]]; then
    printf 'BROKEN   %-6s %-32s HTTP %s for %s\n' "$arch" "$name" "$code" "${matches[0]}"
    return 1
  fi

  # Catch a pattern copied from the x86 row without changing the arch token.
  if [[ "$arch" != "amd64" && "${matches[0]##*/}" =~ (amd64|x86_64|x64) ]]; then
    printf 'WRONGARCH %-5s %-32s %s looks like an x86 build\n' "$arch" "$name" "${matches[0]##*/}"
    return 1
  fi

  # fetch downloads every asset that matches, and _DownloadViaFetch can only
  # move one of them into place, so more than one match is a failure.
  if (( ${#matches[@]} > 1 )); then
    printf 'AMBIG    %-6s %-32s %d assets in %s match: %s\n' "$arch" "$name" "${#matches[@]}" \
      "${RELEASE_TAG[$repo]}" "$(printf '%s ' "${matches[@]##*/}")"
    return 1
  fi
  printf 'OK       %-6s %-32s %s (%s)\n' "$arch" "$name" "${matches[0]##*/}" "${RELEASE_TAG[$repo]}"
}

if $DRY_RUN; then
  for cmd in curl git; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "$cmd is required for -n" >&2; exit 1; }
  done
  FAILED=()
  for i in "${!SPECS[@]}"; do
    _CheckSpec "${NAMES[$i]}" "${SPEC_ARCHES[$i]}" "${SPECS[$i]}" || FAILED+=("${NAMES[$i]}/${SPEC_ARCHES[$i]}")
  done
  if (( ${#FAILED[@]} )); then
    echo "" >&2
    echo "${#FAILED[@]} of ${#SPECS[@]} checks failed: ${FAILED[*]}" >&2
    exit 1
  fi
  exit 0
fi

# ---- real install --------------------------------------------------------

if [[ ! -x "$FETCH" ]]; then
  echo "fetch not found at $FETCH, nothing downloaded" >&2
  exit 1
fi
if ! declare -F _DownloadViaFetch >/dev/null; then
  echo "_DownloadViaFetch is not defined; the caller needs to 'export -f _DownloadViaFetch'" >&2
  exit 1
fi

mkdir -p "$LOCAL_BIN_PATH" "$LOCAL_DATA_PATH/bash-completion/completions"

if $ASSUME_YES || (( ${#WANTED[@]} )) || _Confirm "Download all user-local binaries [Y/n]?" Y; then
  UPDATE_ALL=true
else
  UPDATE_ALL=false
fi

FAILED=()
for i in "${!SPECS[@]}"; do
  if $UPDATE_ALL || _Confirm "Download ${NAMES[$i]} [y/N]?" N; then
    _DownloadViaFetch "${SPECS[$i]}" || FAILED+=("${NAMES[$i]}")
  fi
done
echo "" >&2

if (( ${#FAILED[@]} )); then
  echo "Failed: ${FAILED[*]}" >&2
  exit 1
fi
