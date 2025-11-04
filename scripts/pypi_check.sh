#!/usr/bin/env bash
# Checks if any packages listed in stdin (pkg==ver or pkg>=ver etc.) have newer versions on PyPI

# Make sure "packaging" is installed
python3 -m pip show packaging >/dev/null 2>&1 || {
  echo "Installing missing dependency: packaging..."
  python3 -m pip install --quiet packaging
}

while read -r line; do
  # Skip comments and blanks
  [[ -z "$line" || "$line" =~ ^# ]] && continue

  # Extract package name (before any comparator)
  pkg=$(echo "$line" | sed -E 's/[<>=!~].*//')

  # Extract version (if pinned)
  ver=$(echo "$line" | grep -oP '(?<===)[^ ]+')

  # Query PyPI
  latest=$(curl -s "https://pypi.org/pypi/${pkg}/json" | jq -r '.info.version' 2>/dev/null)

  if [[ "$latest" != "null" && -n "$latest" ]]; then
    if [[ -n "$ver" ]]; then
      # Compare with Python's packaging.version
      newer=$(python3 -c "from packaging.version import Version as V; print(V('$latest') > V('$ver'))")
      if [[ "$newer" == "True" ]]; then
        printf "🔺 %s: %s → %s\n" "$pkg" "$ver" "$latest"
      else
        printf "✅ %s: up-to-date (%s)\n" "$pkg" "$ver"
      fi
    else
      printf "ℹ️  %s: latest version is %s (no pinned version)\n" "$pkg" "$latest"
    fi
  else
    printf "⚠️  %s: not found on PyPI\n" "$pkg"
  fi
done
