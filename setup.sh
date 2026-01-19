#!/bin/bash
# Quick setup script for WPA2 Cracker

echo "Creating .env configuration file..."
cat > .env << 'EOF'
# WPA2 Cracker Configuration

# Use local directory for output (within workspace)
LOCAL_DOWNLOAD_DIR="./handshakes_output"

# Your Raspberry Pi details
PI_HOST="pi@raspberrypi.local"
#PI_HOST="pi@192.168.1.100"  # Use IP if hostname doesn't work

# Wordlist location
WORDLIST="~/wordlist/rockyou.txt"

# Default to wordlist attack
ATTACK_MODE="wordlist"

# CPU mode by default
GPU_MODE="0"
EOF

echo ".env file created!"
echo ""
echo "To use the script:"
echo "1. Edit .env to set your PI_HOST if needed"
echo "2. Run: source .env && ./wpa2crack.sh"
echo ""
echo "For local PCAP files:"
echo "  SOURCE_MODE=local LOCAL_PCAP_DIR=/path/to/pcaps ./wpa2crack.sh"