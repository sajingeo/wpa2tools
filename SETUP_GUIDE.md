# Quick Setup Guide

## Fix Summary

The script has been updated to:
1. **Expand tilde (~) in paths** - Now properly handles `~/wordlist/rockyou.txt`
2. **Create log directory before use** - Prevents "No such file or directory" errors
3. **Skip wordlist check for brute force** - Only checks wordlist when using wordlist mode
4. **Skip SSH tools for local mode** - Only requires SSH when downloading from Pi

## Create Your Configuration

Since .env is gitignored, create it manually:

```bash
# Create .env file
cat > .env << 'EOF'
# Use local directory for output (within workspace)
LOCAL_DOWNLOAD_DIR="./handshakes_output"

# Your Raspberry Pi details
PI_HOST="pi@192.168.1.100"

# Wordlist location
WORDLIST="~/wordlist/rockyou.txt"

# Attack mode
ATTACK_MODE="wordlist"
EOF
```

## Usage Examples

### 1. Basic Usage (with .env)
```bash
source .env && ./wpa2crack.sh
```

### 2. Without .env (inline variables)
```bash
LOCAL_DOWNLOAD_DIR=./output PI_HOST="pi@192.168.1.100" ./wpa2crack.sh
```

### 3. Local PCAP Files
```bash
SOURCE_MODE=local LOCAL_PCAP_DIR=./my_pcaps LOCAL_DOWNLOAD_DIR=./output ./wpa2crack.sh
```

### 4. Brute Force Mode
```bash
ATTACK_MODE=bruteforce LOCAL_DOWNLOAD_DIR=./output ./wpa2crack.sh
```

## Troubleshooting

If you get permission errors:
- Use `LOCAL_DOWNLOAD_DIR=./output` to keep files in the current directory
- Make sure your wordlist exists at `~/wordlist/rockyou.txt`
- For remote mode, ensure you can SSH to your Pi without a password

## Test Without Pi

To test the script without a Raspberry Pi:
```bash
# Create test PCAP files directory
mkdir -p test_pcaps

# Run in local mode
SOURCE_MODE=local LOCAL_PCAP_DIR=./test_pcaps LOCAL_DOWNLOAD_DIR=./output ./wpa2crack.sh
```

Note: You'll need actual PCAP files in the test_pcaps directory for this to work.