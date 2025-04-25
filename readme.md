# 🚀 OpenWebUI & LiteLLM Installation
A one-script solution to deploy your personal AI infrastructure with local LLMs, proxy management, and web UI.

## ✨ What Does This Script Do?

This script automates the deployment of a complete AI stack using Docker containers. In just a few minutes, you'll have:

- **Local LLM capability** via Ollama (with Llama 3.2 1B pre-loaded)
- **LiteLLM API proxy** for consistent API interactions with various models
- **OpenWebUI** - a beautiful interface for interacting with your AI models
- **Nginx Proxy Manager** for easy domain routing and SSL management
- **Portainer** for visual Docker container management
- **PostgreSQL database** for persistent storage
- **Proper security** with UFW firewall configuration

## 🛠️ Components

### Core AI Components
- **Ollama**: Runs lightweight LLMs locally - starts with Llama 3.2 1B
- **LiteLLM**: API proxy providing OpenAI-compatible endpoints for multiple AI models
- **OpenWebUI**: User-friendly interface for interacting with AI models

### Infrastructure
- **Nginx Proxy Manager**: Handles routing, SSL certificates, and domain management
- **Portainer**: Web-based Docker management interface
- **PostgreSQL**: Database for LiteLLM and other components
- **UFW Firewall**: Secures your server while allowing necessary traffic

## 🔒 Security Features

- Sets up UFW firewall with sensible defaults
- Only opens necessary ports (SSH, HTTP, HTTPS)
- Uses Docker networks for container isolation
- Persistent volumes for data security
- Environment variables for sensitive credentials

## 📋 Prerequisites

- Ubuntu-based Linux server (tested on Ubuntu 20.04/22.04)
- Root or sudo access
- Internet connection for downloading Docker and containers

## 🚀 Installation

```bash
# 1. Download the script
wget https://raw.githubusercontent.com/yourusername/ai-stack/main/setup.sh

# 2. Make it executable
chmod +x setup.sh

# 3. Run it
./setup.sh
```

During installation, you'll be prompted for:
- LiteLLM Master and Salt keys (for API security)
- PostgreSQL username and password

## 🌐 Post-Installation Setup

After running the script, you'll need to configure your domains in Nginx Proxy Manager:

1. Access Nginx Proxy Manager admin interface at `http://your-server-ip:81`
2. Default login: admin@example.com / changeme
3. Add the following proxy hosts:
   - `your-domain.com` → `litellm:4000` (LiteLLM API access)
   - `open-webui.your-domain.com` → `open-webui:8080` (AI web interface)
   - `portainer.your-domain.com` → `portainer:9000` (Docker management)

## 🧠 Using Your Local LLM

### Via OpenWebUI
Simply navigate to `https://open-webui.your-domain.com` once configured.

### Via Command Line
```bash
# List available models
docker exec -it $(docker ps --filter name=ollama -q) ollama list

# Run a quick prompt
docker exec -it $(docker ps --filter name=ollama -q) ollama run llama3.2:1b \
  --prompt "Hello Llama!"
```

### Via API (OpenAI-compatible)
```bash
curl -X POST https://your-domain.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -d '{
    "model": "ollama/llama3.2:1b",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

## 🛠️ Management

- **Portainer**: Manage Docker containers, volumes, and networks
- **Nginx Proxy Manager**: Configure domains, SSL certificates, and access rules
- **OpenWebUI**: Configure chat settings, model parameters, and user preferences

## 📝 Customization

The script creates a stack directory at `~/ai-stack` containing:
- `.env` file for environment variables
- `docker-compose.yml` for service configuration

Modify these files to customize your deployment.

## 🔄 Updates

To update components:
```bash
cd ~/ai-stack
docker compose pull
docker compose up -d
```

## 📚 Additional Models

Add more Ollama models:
```bash
OLLAMA_CID=$(docker ps --filter name=ollama -q)
docker exec -it $OLLAMA_CID ollama pull mistral:7b
```

## 📧 Support

If you encounter any issues, please open an issue on GitHub or reach out to me directly.

---

⭐ If you find this useful, please star the repository! ⭐
