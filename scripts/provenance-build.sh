#!/bin/bash
# Generates a proof.json for each given prediction.md file using OpenTimestamps.
set -e
shopt -s expand_aliases

# ots-cli.js should be in PATH or alias it here
# install via: npm install -g ots-cli.js
alias ots='ots-cli.js'

script_name="${BASH_SOURCE[0]##*/}"

# If no arguments, show usage
if [ $# -eq 0 ]; then
  echo "Usage: ./$script_name path/to/prediction1.md [path/to/prediction2.md ...]"
  echo "       ./$script_name predictions/*.md"
  exit 1
fi

# Process each file passed as argument
for FILE in "$@"; do
  # Skip if not a regular file
  [ -f "$FILE" ] || continue

  echo "Processing: $FILE"

  DIR=$(dirname "$FILE")
  BASENAME=$(basename "$FILE")
  BASENAME_NOEXT="${BASENAME%.*}"
  SHA256=$(sha256sum "$FILE" | awk '{print $1}')
  CREATED=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Stamp the file with OpenTimestamps (if not already stamped)
  ots stamp "$FILE" 2>/dev/null || true

  # ---- Derive a unique ID ----
  # Use realpath to get absolute path
  FULL_PATH="$(realpath "$FILE" 2>/dev/null || echo "$FILE")"

  # Get Git root (fallback to current directory if not in a repo)
  if git rev-parse --show-toplevel >/dev/null 2>&1; then
    GIT_ROOT="$(git rev-parse --show-toplevel)"
  else
    GIT_ROOT="$(pwd)"
  fi

  # Normalize paths for cross-platform (Git Bash / WSL / Linux / macOS)
  # If cygpath is available (Git Bash), use it; otherwise, use realpath
  if command -v cygpath >/dev/null 2>&1; then
    FULL_PATH="$(cygpath -u "$FULL_PATH")"
    GIT_ROOT="$(cygpath -u "$GIT_ROOT")"
  fi

  # Remove repo root to get relative path
  REL_PATH="${FULL_PATH#$GIT_ROOT/}"
  # If REL_PATH equals FULL_PATH, fallback to basename
  if [ "$REL_PATH" = "$FULL_PATH" ]; then
    REL_PATH="$BASENAME"
  fi

  # Convert path separators to dots and remove file extension
  ID_PATH="${REL_PATH%/*}"
  ID_PATH="${ID_PATH//\//.}"
  if [ -n "$ID_PATH" ]; then
    ID="${ID_PATH}.${BASENAME_NOEXT}"
  else
    ID="$BASENAME_NOEXT"
  fi
  # ---- End ID derivation ----

  # Write proof.json
  cat > "$DIR/$BASENAME.proof.json" <<EOF
{
  "id": "$ID",
  "file": "$BASENAME",
  "sha256": "$SHA256",
  "ots_file": "$BASENAME.ots",
  "timestamp_method": "opentimestamps",
  "created_utc": "$CREATED"
}
EOF

  echo "  -> Generated: $DIR/$BASENAME.proof.json (id: $ID)"
done

echo "All done."