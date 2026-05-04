#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# One-click Ghost blog deployment on Hetzner VPS via Cloudflare Tunnel
#
# Required environment variables:
#   HETZNER_API_TOKEN   — Hetzner Cloud API token
#   CF_TUNNEL_TOKEN     — Cloudflare Tunnel token (see README for how to get it)
#
# Optional environment variables:
#   SERVER_NAME         — name of the VPS (default: ghost-blog)
#   SERVER_TYPE         — Hetzner server type (default: cx22, ~4$/mo)
#   SERVER_LOCATION     — Hetzner datacenter (default: nbg1 = Nuremberg)
#   SERVER_IMAGE        — OS image (default: ubuntu-24.04)
# ---------------------------------------------------------------------------

: "${HETZNER_API_TOKEN:?Error: HETZNER_API_TOKEN is not set}"
: "${CF_TUNNEL_TOKEN:?Error: CF_TUNNEL_TOKEN is not set}"

SERVER_NAME="${SERVER_NAME:-ghost-blog}"
SERVER_TYPE="${SERVER_TYPE:-cx22}"
SERVER_LOCATION="${SERVER_LOCATION:-nbg1}"
SERVER_IMAGE="${SERVER_IMAGE:-ubuntu-24.04}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check hcloud CLI is installed
if ! command -v hcloud &>/dev/null; then
  echo "Error: hcloud CLI not found."
  echo "Install it from: https://github.com/hetznercloud/cli/releases"
  exit 1
fi

# Inject the Cloudflare tunnel token into cloud-init
CLOUD_INIT_FILE=$(mktemp)
sed "s|__CF_TUNNEL_TOKEN__|${CF_TUNNEL_TOKEN}|g" \
  "${SCRIPT_DIR}/cloud-init.yaml" > "${CLOUD_INIT_FILE}"

echo "==> Creating Hetzner VPS '${SERVER_NAME}'..."
echo "    Type: ${SERVER_TYPE} | Location: ${SERVER_LOCATION} | Image: ${SERVER_IMAGE}"

HCLOUD_TOKEN="${HETZNER_API_TOKEN}" hcloud server create \
  --name "${SERVER_NAME}" \
  --type "${SERVER_TYPE}" \
  --image "${SERVER_IMAGE}" \
  --location "${SERVER_LOCATION}" \
  --user-data-from-file "${CLOUD_INIT_FILE}"

rm -f "${CLOUD_INIT_FILE}"

SERVER_IP=$(HCLOUD_TOKEN="${HETZNER_API_TOKEN}" hcloud server describe "${SERVER_NAME}" \
  -o format='{{.PublicNet.IPv4.IP}}')

echo ""
echo "==> VPS created successfully!"
echo "    Public IP : ${SERVER_IP}"
echo "    Note      : Port 22 is firewalled — SSH is only available via Cloudflare Tunnel"
echo ""
echo "==> Next steps:"
echo "    1. Wait 2-3 minutes for cloud-init to complete."
echo "    2. In your Cloudflare Tunnel dashboard, add a public hostname:"
echo "         ghost.<your-domain>  ->  http://localhost:2368"
echo "    3. For SSH access, add another hostname (or use the same tunnel):"
echo "         ssh.<your-domain>    ->  ssh://localhost:22"
echo "       Then connect with:"
echo "         cloudflared access ssh --hostname ssh.<your-domain>"
echo ""
echo "    Ghost admin: https://ghost.<your-domain>/ghost"
