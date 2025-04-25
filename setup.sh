#!/usr/bin/env bash
# install_and_deploy_full.sh
# Installs Docker + Compose v2, locks down the host firewall, 
# and deploys the AI stack entirely in Docker (Docker-native networking).

set -euo pipefail

echo "=== 1/7: Gathering credentials ==="
read -rp "LiteLLM Master Key: "   LITELLM_MASTER_KEY
read -rp "LiteLLM Salt   Key: "   LITELLM_SALT_KEY
read -rp "Postgres username   : " POSTGRES_USER
read -rsp "Postgres password   : " POSTGRES_PASSWORD
echo

echo "=== 2/7: Installing Docker Engine & Compose v2 ==="
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg lsb-release ufw
sudo install -m0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo "=== 2.5/7: Configuring UFW firewall ==="
# Allow SSH (change 22 to your SSH port if different)
sudo ufw allow ssh
# Allow web traffic
sudo ufw allow http    # port 80/tcp
sudo ufw allow https   # port 443/tcp
# Deny everything else by default
sudo ufw default deny incoming
sudo ufw default allow outgoing
# Enable UFW non‑interactive
echo "y" | sudo ufw enable

echo "=== 3/7: Preparing stack directory ==="
STACK_DIR="$HOME/ai-stack"
mkdir -p "$STACK_DIR"
cd "$STACK_DIR"

echo "=== 4/7: Writing .env file ==="
cat > .env <<EOF
# --- global secrets / runtime configuration ---
LITELLM_MASTER_KEY=${LITELLM_MASTER_KEY}
LITELLM_SALT_KEY=${LITELLM_SALT_KEY}
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

# service‑specific helpers
DATABASE_URL=postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/litellm_db
STORE_MODEL_IN_DB=True
EOF

echo "=== 5/7: Writing docker-compose.yml ==="
cat > docker-compose.yml <<'EOF'
version: "3.11"

networks:
  proxy-tier:
    driver: bridge

services:
  npm:
    image: jc21/nginx-proxy-manager:latest
    restart: unless-stopped
    networks:
      - proxy-tier
    ports:
      - "80:80"
      - "443:443"
      - "81:81"
    volumes:
      - npm_data:/data
      - npm_letsencrypt:/etc/letsencrypt

  portainer:
    image: portainer/portainer-ce:latest
    restart: unless-stopped
    networks:
      - proxy-tier
    command: -H unix:///var/run/docker.sock
    expose:
      - "9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data

  db:
    image: postgres:16
    restart: always
    networks:
      - proxy-tier
    environment:
      POSTGRES_DB: litellm_db
      POSTGRES_USER: "${POSTGRES_USER}"
      POSTGRES_PASSWORD: "${POSTGRES_PASSWORD}"
    volumes:
      - pg_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -d litellm_db -U ${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5

  ollama:
    image: ollama/ollama:latest
    restart: unless-stopped
    networks:
      - proxy-tier
    command: ["serve"]
    environment:
      - OLLAMA_MODELS=llama3.2:1b
      - OLLAMA_HOST=0.0.0.0:11434
    expose:
      - "11434"
    volumes:
      - ollama_data:/root/.ollama

  litellm:
    image: ghcr.io/berriai/litellm:main-stable
    restart: unless-stopped
    networks:
      - proxy-tier
    env_file:
      - .env
    depends_on:
      db:
        condition: service_healthy
    expose:
      - "4000"
    volumes:
      - litellm_data:/root/.cache/litellm
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:4000/health/liveliness"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    restart: unless-stopped
    networks:
      - proxy-tier
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
      - PROXY=http://litellm:4000
    depends_on:
      - ollama
      - litellm
    expose:
      - "8080"
    volumes:
      - openwebui_data:/app/backend/data

volumes:
  npm_data:
  npm_letsencrypt:
  portainer_data:
  pg_data:
  litellm_data:
  openwebui_data:
  ollama_data:
EOF

echo "=== 6/7: Deploying stack ==="
docker compose up -d

echo "=== 7/7: Pulling Llama model in Ollama ==="
OLLAMA_CID=$(docker ps --filter name=ollama -q)
echo "Pulling llama3.2:1b in container $OLLAMA_CID..."
docker exec -u root -it "$OLLAMA_CID" ollama pull llama3.2:1b

echo -e "\n✅  Stack is live!"
echo "👉  In Nginx Proxy Manager, point your Proxy Hosts at:"
echo "     • your-domain.com → litellm:4000"
echo "     • open-webui.your-domain.com → open-webui:8080"
echo "     • portainer.your-domain.com → portainer:9000"
echo
echo "▶️  To use the Ollama CLI:"
echo "    docker exec -it $OLLAMA_CID ollama list"
echo "    docker exec -it $OLLAMA_CID ollama run llama3.2:1b --prompt \"Hello Llama!\""
