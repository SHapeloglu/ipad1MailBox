#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENDOR_DIR="$ROOT_DIR/Vendor/mbedtls"
CONFIG_SRC="$ROOT_DIR/Config/IMBMBEDTLSConfig.h"
CONFIG_DST="$VENDOR_DIR/include/mbedtls/mbedtls_config.h"
CA_DST="$ROOT_DIR/Resources/isrgrootx2.pem"
MBEDTLS_TAG="mbedtls-3.6.7"
MBEDTLS_URL="https://github.com/Mbed-TLS/mbedtls.git"
CA_URL="https://letsencrypt.org/certs/isrg-root-x2.pem"

mkdir -p "$ROOT_DIR/Vendor"

if [[ ! -d "$VENDOR_DIR/.git" ]]; then
    echo "[bootstrap] Fetching Mbed TLS $MBEDTLS_TAG..."
    rm -rf "$VENDOR_DIR"
    git clone --depth 1 --branch "$MBEDTLS_TAG" "$MBEDTLS_URL" "$VENDOR_DIR"
else
    echo "[bootstrap] Mbed TLS checkout already exists."
fi

if [[ ! -f "$CONFIG_SRC" ]]; then
    echo "[bootstrap] Missing config: $CONFIG_SRC" >&2
    exit 1
fi

cp "$CONFIG_SRC" "$CONFIG_DST"
echo "[bootstrap] Installed iPad1MailBox Mbed TLS config."

if command -v curl >/dev/null 2>&1; then
    curl -fsSL --retry 3 "$CA_URL" -o "$CA_DST.tmp"
elif command -v wget >/dev/null 2>&1; then
    wget -qO "$CA_DST.tmp" "$CA_URL"
else
    echo "[bootstrap] curl or wget is required to download the CA root." >&2
    exit 1
fi

if ! grep -q "BEGIN CERTIFICATE" "$CA_DST.tmp"; then
    echo "[bootstrap] Downloaded CA file is not a PEM certificate." >&2
    rm -f "$CA_DST.tmp"
    exit 1
fi

mv "$CA_DST.tmp" "$CA_DST"
rm -f "$ROOT_DIR/Resources/isrgrootx1.pem"
echo "[bootstrap] Installed ISRG Root X2 trust anchor."
echo "[bootstrap] Ready. Run: make clean && make package FINALPACKAGE=1"
