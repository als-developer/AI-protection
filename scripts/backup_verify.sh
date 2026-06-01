#!/bin/bash
set -euo pipefail

BACKUP_FILE=${1:-}

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup_file.gpg>"
    exit 1
fi

echo "Verifying backup integrity: $BACKUP_FILE"

# Verify GPG signature
if gpg --verify "$BACKUP_FILE" 2>/dev/null; then
    echo "✅ GPG signature valid"
else
    echo "❌ GPG signature invalid"
    exit 1
fi

# Test decryption
TEMP_DIR=$(mktemp -d)
if gpg --batch --decrypt "$BACKUP_FILE" > "$TEMP_DIR/test.tar.gz" 2>/dev/null; then
    echo "✅ Decryption successful"
else
    echo "❌ Decryption failed"
    exit 1
fi

# Test extraction
if tar -tzf "$TEMP_DIR/test.tar.gz" > /dev/null 2>&1; then
    echo "✅ Archive integrity verified"
else
    echo "❌ Archive corrupted"
    exit 1
fi

# Cleanup
rm -rf "$TEMP_DIR"

echo "✅ Backup is valid and can be restored!"
