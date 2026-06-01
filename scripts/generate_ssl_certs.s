#!/bin/bash
set -euo pipefail

DOMAIN=${1:-api.bioshield.secure-bank.internal}
CERT_DIR="/etc/ssl/certs"
KEY_DIR="/etc/ssl/private"

echo "Generating SSL certificates for $DOMAIN..."

# Create directories
sudo mkdir -p $CERT_DIR $KEY_DIR

# Generate private key
sudo openssl genrsa -out $KEY_DIR/bioshield.key 2048

# Generate CSR
sudo openssl req -new -key $KEY_DIR/bioshield.key \
  -out /tmp/bioshield.csr \
  -subj "/C=TZ/ST=Dar es Salaam/L=Dar es Salaam/O=BioShield/CN=$DOMAIN"

# Generate self-signed certificate (for development)
sudo openssl x509 -req -days 365 \
  -in /tmp/bioshield.csr \
  -signkey $KEY_DIR/bioshield.key \
  -out $CERT_DIR/bioshield.crt

# Set permissions
sudo chmod 600 $KEY_DIR/bioshield.key
sudo chmod 644 $CERT_DIR/bioshield.crt

# Create PEM bundle for HAProxy/NGINX
sudo cat $CERT_DIR/bioshield.crt $KEY_DIR/bioshield.key > $CERT_DIR/bioshield.pem

echo "✅ SSL certificates generated successfully!"
echo "Certificate: $CERT_DIR/bioshield.crt"
echo "Private key: $KEY_DIR/bioshield.key"
