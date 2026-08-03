#!/usr/bin/env bash
#
# Deploy the K Legal website to the Websupport FTP server (klegal.sk/web).
#
# The FTP password is read from ~/.klegal.ftppass (should be chmod 600).
# Create it once with:
#     printf '%s' 'YOUR_FTP_PASSWORD' > ~/.klegal.ftppass && chmod 600 ~/.klegal.ftppass
#
# Usage:  ./deploy.sh
#
set -euo pipefail

FTP_HOST="webftp.r1.websupport.sk"
FTP_USER="klegal.sk"
FTP_DIR="klegal.sk/web"
PASSFILE="${KLEGAL_FTPPASS:-$HOME/.klegal.ftppass}"

# Only these files are published (keeps private originals/PDFs off the server).
FILES=(index.html favicon.png eva-1x1.jpg rasto-1x1.jpg kosice.png obchod.jpg spravne.jpg obcan.jpg)

# --- run from the script's own directory ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# --- read the password ---
if [[ ! -f "$PASSFILE" ]]; then
  echo "Error: password file not found: $PASSFILE" >&2
  echo "Create it with:  printf '%s' 'YOUR_FTP_PASSWORD' > $PASSFILE && chmod 600 $PASSFILE" >&2
  exit 1
fi
FTP_PASS="$(tr -d '\r\n' < "$PASSFILE")"
if [[ -z "$FTP_PASS" ]]; then
  echo "Error: password file is empty: $PASSFILE" >&2
  exit 1
fi

# --- hand credentials to curl via a temp config, so the password
#     never shows up in `ps`/argv ---
CFG="$(mktemp)"
chmod 600 "$CFG"
trap 'rm -f "$CFG"' EXIT
printf 'user "%s:%s"\n' "$FTP_USER" "$FTP_PASS" > "$CFG"

BASE="ftp://${FTP_HOST}/${FTP_DIR}"
echo "Deploying to ${BASE}/"

fail=0
for f in "${FILES[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "  MISSING  $f (not found locally)"
    fail=1
    continue
  fi
  if curl -fsS --connect-timeout 30 --ftp-create-dirs -K "$CFG" -T "$f" "$BASE/$f"; then
    echo "  OK       $f"
  else
    echo "  FAIL     $f"
    fail=1
  fi
done

if [[ "$fail" -ne 0 ]]; then
  echo "Deploy finished with errors." >&2
  exit 1
fi
echo "Deploy complete — all files uploaded to ${FTP_DIR}/"
