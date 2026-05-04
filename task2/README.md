# Task 2 — Ghost Blog on Hetzner VPS via Cloudflare Tunnel

Deploys a [Ghost](https://ghost.org/) blog on a Hetzner Cloud VPS with **no public SSH access** — all connectivity goes through a [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/).

## Architecture

```
Your machine
    │
    │  hcloud API (HTTPS)
    ▼
Hetzner VPS
    ├── UFW firewall: only ports 80 & 443 open
    ├── Ghost (Docker) — listens on localhost:2368
    └── cloudflared — outbound tunnel to Cloudflare
            │
            │  encrypted outbound connection
            ▼
        Cloudflare Edge
            ├── ghost.<domain>  →  Ghost blog (public)
            └── ssh.<domain>    →  SSH (private, via Cloudflare Access)
```

SSH is only reachable through the Cloudflare Tunnel — port 22 is blocked by UFW on the public interface.

## Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| `hcloud` CLI | Create Hetzner VPS | [hetznercloud/cli](https://github.com/hetznercloud/cli/releases) |
| Hetzner account | VPS hosting | [console.hetzner.cloud](https://console.hetzner.cloud/) |
| Cloudflare account | Tunnel + DNS | [dash.cloudflare.com](https://dash.cloudflare.com/) — free plan is sufficient |
| A domain on Cloudflare | Public hostname for Ghost and SSH | Add it in Cloudflare dashboard |

## Step 1 — Get a Hetzner API Token

1. Go to [Hetzner Cloud Console](https://console.hetzner.cloud/) → your project → **Security → API Tokens**
2. Create a token with **Read & Write** permissions
3. Save it — you will need it as `HETZNER_API_TOKEN`

## Step 2 — Get a Cloudflare Tunnel Token

1. Go to [Cloudflare Zero Trust](https://one.dash.cloudflare.com/) → **Networks → Tunnels**
2. Click **Create a tunnel** → choose **Cloudflared**
3. Give it a name (e.g. `ghost-blog`)
4. Copy the tunnel token shown on the next screen — this is your `CF_TUNNEL_TOKEN`
5. Add public hostnames (you can do this now or after deployment):
   - `ghost.<your-domain>` → Service: `HTTP`, URL: `localhost:2368`
   - `ssh.<your-domain>` → Service: `SSH`, URL: `localhost:22`

## Step 3 — Deploy

```bash
cd task2

export HETZNER_API_TOKEN="your-hetzner-token"
export CF_TUNNEL_TOKEN="your-cloudflare-tunnel-token"

# Optional overrides:
# export SERVER_NAME="ghost-blog"
# export SERVER_TYPE="cx22"        # ~4 USD/month, 2 vCPU, 4 GB RAM
# export SERVER_LOCATION="nbg1"    # nbg1=Nuremberg, fsn1=Falkenstein, hel1=Helsinki

bash deploy.sh
```

Wait **2–3 minutes** for cloud-init to complete on the VPS.

## Step 4 — Connect

### Ghost blog
Open `https://ghost.<your-domain>` in the browser.
Set up your blog at `https://ghost.<your-domain>/ghost`.

### SSH via Cloudflare Tunnel

Install `cloudflared` locally:
```bash
# macOS
brew install cloudflared

# Linux
curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
  -o /usr/local/bin/cloudflared && chmod +x /usr/local/bin/cloudflared
```

Add to your local `~/.ssh/config`:
```
Host ssh.<your-domain>
    ProxyCommand cloudflared access ssh --hostname %h
    User root
```

Connect:
```bash
ssh ssh.<your-domain>
```

## What Happens on the VPS (cloud-init)

1. **UFW firewall** — blocks all inbound traffic except ports 80 and 443; port 22 is not exposed publicly
2. **Docker + Ghost** — Ghost 5 runs in a container, listening only on `localhost:2368`; data is persisted in a Docker volume
3. **cloudflared** — installed as a systemd service with the provided tunnel token; creates an encrypted outbound connection to Cloudflare that routes traffic to Ghost and SSH

## Cleanup

```bash
HCLOUD_TOKEN="${HETZNER_API_TOKEN}" hcloud server delete ghost-blog
```
