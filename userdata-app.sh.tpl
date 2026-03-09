#!/bin/bash

# Update and install dependencies
apt-get update
apt-get -y install git curl build-essential mariadb-client

# Install Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

export GITHUB_USERNAME="subhamgrv"
export GITHUB_TOKEN="${github_token}"


# Clone the GitHub repo
git clone https://$GITHUB_USERNAME:$GITHUB_TOKEN@github.com/subhamgrv/Change-Data-Capture.git /opt/app

# Fix ownership so ubuntu user can access it
chown -R ubuntu:ubuntu /opt/app

# Run everything as ubuntu user to avoid root conflicts
sudo -u ubuntu bash <<'EOF'

# --- Backend Setup ---
cd /opt/app/Backend
npm install --legacy-peer-deps

export DB_HOST=${db_host}
export DB_USER=Admin
export DB_PASSWORD='abcd@1234'
export DATABASE=registrysystem
export JWT_SECRET_KEY=supersecretrandomstring42
export SERVER_PORT=8000
export HOST=0.0.0.0  
nohup npm start > /opt/app/backend.log 2>&1 &

# --- Frontend Setup ---
cd /opt/app/Frontend
npm install --legacy-peer-deps
npm install react-is --legacy-peer-deps

# Set API endpoint (if your React app reads from process.env.* at build time)
export REACT_APP_API_URL=${public_api_url}

# Expose React on all interfaces for remote access
nohup npm start -- --host=0.0.0.0 > /opt/app/frontend.log 2>&1 &

EOF


#userdata-db.sh.tpl


# .sh is was not able to work because it can't inject dynamic Terraform values like DB or API IPs during deployment.