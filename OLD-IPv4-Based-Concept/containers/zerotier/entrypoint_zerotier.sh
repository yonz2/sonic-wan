#!/bin/sh

# Exit immediately if a command exits with a non-zero status.
set -e

echo '🚀 Starting ZeroTier container...'

if [ -f /var/lib/zerotier-one/identity.secret ]; then
  echo '✅ Using static ZeroTier identity'
else
  echo '⚠️ No identity found, a new one will be generated'
fi

# Give the OS a moment to settle network interfaces, etc.
sleep 3

echo '✅ ZeroTier service started.'
echo 'You can now join your network using: docker exec -it zerotier zerotier-cli join <network-id>'

# This is the crucial part:
# Replace the shell with the command passed as arguments to the script.
exec "$@"
