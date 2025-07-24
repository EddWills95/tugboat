#!/bin/bash

set -e

# 1. Install Docker if not present
if ! command -v docker &> /dev/null; then
  echo "Installing Docker..."
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker $USER
  echo "Docker installed. Please log out and back in, then re-run this script."
  exit 1
fi

# 2. Clone the repo (if not already present)
if [ ! -d "tugboat" ]; then
  git clone https://github.com/yourusername/tugboat.git
  cd tugboat
else
  cd tugboat
  git pull
fi

# 3. Build/pull Docker images
docker compose pull
docker compose build

# 4. Run database migrations
docker compose run --rm web rails db:setup

# 5. Start the app
docker compose up -d

echo "Installation complete! The app should now be running."
