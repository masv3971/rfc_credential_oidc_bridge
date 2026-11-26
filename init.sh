#!/bin/bash
set -euo pipefail

if command -v gh >/dev/null 2>&1; then
  echo "gh already installed: $(gh --version | head -1)"
else
  sudo mkdir -p -m 755 /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y gh
fi

if gh auth status >/dev/null 2>&1; then
  gh auth status
else
  gh auth login
fi

sudo curl -fsSL -o /usr/local/bin/sync-skills.sh \
  https://github.com/masv3971/coding-skills/releases/latest/download/sync-skills.sh
sudo chmod +x /usr/local/bin/sync-skills.sh
