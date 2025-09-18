#!/bin/bash

# Batch MySQL Setup Script
# Usage: ./batch-mysql-setup.sh <hosts_file> <ssh_key>

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <hosts_file> <ssh_key>"
    echo "Example: $0 hosts.txt ~/.ssh/id_rsa"
    exit 1
fi

HOSTS_FILE=$1
SSH_KEY=$2

if [ ! -f "$HOSTS_FILE" ]; then
    echo "Hosts file $HOSTS_FILE not found!"
    exit 1
fi

echo "Starting batch MySQL setup..."
echo "Hosts file: $HOSTS_FILE"
echo "SSH key: $SSH_KEY"
echo ""

# Read hosts and setup MySQL on each
while IFS= read -r host; do
    if [ -n "$host" ] && [[ ! "$host" =~ ^# ]]; then
        echo "Setting up MySQL on $host..."
        
        # Use the remote setup script
        ./remote-mysql-setup.sh "$host" "$SSH_KEY" "myapp_db" "myapp_user" "SecurePassword123!"
        
        echo "Completed setup on $host"
        echo "----------------------------------------"
    fi
done < "$HOSTS_FILE"

echo "Batch MySQL setup completed for all hosts!"