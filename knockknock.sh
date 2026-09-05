#!/bin/sh
# fwknop-knock.sh <salt> — derive keys from passphrase, knock, clean up
set -eu

SPA_SERVER=203.0.113.10    # your fwknopd server
SPA_PORT=62201             # must match the server's fwknopd.conf
ACCESS=tcp/22
ALLOW_IP=resolve           # or your known external IP, e.g. 203.0.113.50

[ -n "${1:-}" ] || { echo "usage: $0 <salt>" >&2; exit 1; }
SALT=$1

RC=$HOME/.fwknoprc
[ -e "$RC" ] && { echo "$RC exists (rm it if it's the auto-generated template)" >&2; exit 1; }
trap 'shred -u "$RC" 2>/dev/null || rm -f "$RC"' EXIT

read -rs PASS; echo
[ -n "$PASS" ] || { echo "empty passphrase" >&2; exit 1; }

# Two keys from one passphrase, distinct salt contexts, sized to match --key-gen output
ENC_KEY=$(openssl kdf -binary -keylen 32 \
    -kdfopt digest:SHA256 -kdfopt iter:600000 \
    -kdfopt salt:"$SALT-enc" -kdfopt pass:"$PASS" PBKDF2 | base64 -w0)
HMAC_KEY=$(openssl kdf -binary -keylen 64 \
    -kdfopt digest:SHA256 -kdfopt iter:600000 \
    -kdfopt salt:"$SALT-hmac" -kdfopt pass:"$PASS" PBKDF2 | base64 -w0)

umask 077
{
    echo "[default]"
    echo "SPA_SERVER=$SPA_SERVER"
    echo "SPA_SERVER_PORT=$SPA_PORT"
    echo "SPA_SERVER_PROTO=udp"
    echo "ACCESS=$ACCESS"
    echo "ALLOW_IP=$ALLOW_IP"
    echo "DIGEST_TYPE=sha256"
    echo "FW_TIMEOUT=30"
    echo "KEY_BASE64=$ENC_KEY"
    echo "HMAC_KEY_BASE64=$HMAC_KEY"
} > "$RC"

fwknop --use-hmac
