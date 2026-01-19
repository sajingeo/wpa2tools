# WPA2 Handshake Cracker

An automated tool for downloading WPA/WPA2 handshakes from a Raspberry Pi (Pwnagotchi), converting them to hashcat format, and cracking them using wordlist attacks.

## Features

- 🔐 Automated SSH connection to Raspberry Pi
- 📁 Support for local PCAP file directories
- 📦 Bulk download and extraction of handshake files
- 🔄 Automatic conversion from PCAP to HC22000 format
- 🚀 Parallel hashcat cracking with customizable wordlists
- ⚡ GPU acceleration support with performance modes
- 🎯 Brute force attack mode with customizable patterns
- 📝 Organized output with .cracked files for each network
- 📊 Detailed logging and summary reports
- 🎨 Color-coded terminal output for better readability

## Table of Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Setup](#setup)
- [Usage](#usage)
- [Configuration](#configuration)
- [Output Structure](#output-structure)
- [Troubleshooting](#troubleshooting)
- [Security Notes](#security-notes)

## Requirements

### System Requirements
- Linux or macOS (tested on both)
- Bash shell
- SSH access to your Raspberry Pi

### Required Tools
- `ssh` - For remote connection
- `scp` - For secure file transfer
- `tar` - For archive creation/extraction
- `hcxpcapngtool` - For PCAP to HC22000 conversion (from hcxtools)
- `hashcat` - For password cracking
- `xxd` - For hex conversion (usually pre-installed)

### Wordlists
- Default: `~/wordlist/rockyou.txt`
- Can be customized via environment variable

## Installation

### 1. Install Dependencies

#### On Ubuntu/Debian:
```bash
sudo apt update
sudo apt install openssh-client hashcat xxd
```

#### On macOS:
```bash
brew install hashcat
```

### 2. Install hcxtools

```bash
# Clone the repository
cd ~/Downloads
git clone https://github.com/ZerBea/hcxtools.git
cd hcxtools

# Install dependencies (Ubuntu/Debian)
sudo apt install libssl-dev libcurl4-openssl-dev pkg-config make gcc

# Compile
make -j $(nproc)

# Install to /usr/local/bin (works on both Linux and macOS)
sudo make install PREFIX=/usr/local

# On macOS, if you get permission errors, try:
# make install PREFIX=/usr/local

# Clean up
cd ..
rm -rf hcxtools
```

**Note for macOS users**: If you encounter permission errors, you may need to:
1. Use `PREFIX=/usr/local` when installing
2. Or manually copy the binaries: `sudo cp hcxpcapngtool /usr/local/bin/`
3. Ensure `/usr/local/bin` is in your PATH

### 3. Download Wordlists

```bash
# Create wordlist directory in your home folder
mkdir -p ~/wordlist
cd ~/wordlist
# Download rockyou.txt
wget https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt
```

### 4. Clone This Repository

```bash
git clone <your-repo-url>
cd wpa2tools
chmod +x wpa2crack.sh
```

## Setup

### 1. SSH Key Configuration

Generate SSH keys for passwordless authentication:

```bash
# Generate SSH key pair
ssh-keygen -t rsa -b 4096 -f ~/.ssh/pwnagotchi_rsa

# Copy public key to Raspberry Pi
ssh-copy-id -i ~/.ssh/pwnagotchi_rsa.pub pi@<your-pi-ip>
```

### 2. Configure SSH Client

Add to `~/.ssh/config`:

```
Host pwnagotchi
    HostName <your-pi-ip>
    User pi
    IdentityFile ~/.ssh/pwnagotchi_rsa
    StrictHostKeyChecking no
```

### 3. Raspberry Pi Setup

On your Pwnagotchi/Raspberry Pi:

```bash
# Create handshakes directory if it doesn't exist
mkdir -p /home/pi/handshakes

# If using Pwnagotchi, update config.toml:
sudo nano /etc/pwnagotchi/config.toml
# Change: bettercap.handshakes = "/home/pi/handshakes"
```

## Usage

### Basic Usage

```bash
./wpa2crack.sh
```

### With Custom Configuration

```bash
# Custom Pi host
PI_HOST="pi@192.168.1.100" ./wpa2crack.sh

# Use local PCAP files instead of downloading from Pi
SOURCE_MODE=local LOCAL_PCAP_DIR=/path/to/pcaps ./wpa2crack.sh

# Custom wordlist
WORDLIST="/path/to/custom/wordlist.txt" ./wpa2crack.sh

# GPU accelerated attack
GPU_MODE=2 ./wpa2crack.sh

# Brute force attack with 8 digits
ATTACK_MODE=bruteforce BRUTE_PATTERN='?d?d?d?d?d?d?d?d' GPU_MODE=2 ./wpa2crack.sh

# Local PCAP files with GPU brute force
SOURCE_MODE=local LOCAL_PCAP_DIR=./captures ATTACK_MODE=bruteforce GPU_MODE=2 ./wpa2crack.sh

# Combined settings
PI_HOST="pi@pwnagotchi.local" WORDLIST="~/wordlist/wifi.txt" GPU_MODE=2 ./wpa2crack.sh
```

### What the Script Does

1. **Source Selection** - Choose between remote (Pi) or local PCAP files
2. **Remote Mode**: Connects to Raspberry Pi via SSH
3. **Local Mode**: Uses PCAP files from specified directory
4. **Creates tar archive** of all .pcap files (remote mode only)
5. **Downloads archive** to local machine (remote mode only)
6. **Extracts/Copies files** to organized directory structure
7. **Converts PCAP files** to HC22000 format using hcxpcapngtool
8. **Runs hashcat** on each converted file
9. **Saves cracked passwords** to .cracked files
10. **Generates summary report** with statistics

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SOURCE_MODE` | `remote` | Source mode: `remote` (Pi) or `local` (directory) |
| `LOCAL_PCAP_DIR` | - | Path to local PCAP files (required for local mode) |
| `PI_HOST` | `pi@raspberrypi.local` | SSH connection string for Raspberry Pi |
| `WORDLIST` | `~/wordlist/rockyou.txt` | Path to wordlist file |
| `ATTACK_MODE` | `wordlist` | Attack mode: `wordlist` or `bruteforce` |
| `GPU_MODE` | `0` | GPU acceleration: `0`=CPU, `1`=GPU, `2`=GPU high performance |
| `BRUTE_PATTERN` | `?u?l?l?l?l?l?l?l` | Mask pattern for brute force attacks |
| `MIN_LENGTH` | `8` | Minimum password length for brute force |
| `MAX_LENGTH` | `8` | Maximum password length for brute force |

### Hashcat Mask Characters

When using brute force mode, you can use these mask characters:

- `?l` = lowercase letters (a-z)
- `?u` = uppercase letters (A-Z)
- `?d` = digits (0-9)
- `?s` = special characters
- `?a` = all characters

Example patterns:
- `?d?d?d?d?d?d?d?d` - 8 digits (common for WPS PINs)
- `?u?l?l?l?l?l?l?l` - 1 uppercase + 7 lowercase
- `?l?l?l?l?d?d?d?d` - 4 letters + 4 digits

### Directory Structure

The script creates the following structure in `~/Downloads/handshakes/`:

```
~/Downloads/handshakes/
├── pcap/                 # Downloaded PCAP files
├── hc22000/             # Converted HC22000 files
├── cracked/             # Successfully cracked passwords
├── logs/                # Conversion and hashcat logs
├── report_TIMESTAMP.txt # Summary report
└── wpa2crack_TIMESTAMP.log # Main script log
```

## Output Structure

### .cracked Files

Each successfully cracked network gets a `.cracked` file in the `cracked/` directory:

```
SSID: MyHomeNetwork
Password: password123
Cracked on: Mon Jan 19 10:30:45 EST 2026
Source file: MyHomeNetwork_aabbccddeeff.pcap
---
```

If the same SSID is cracked multiple times, entries are appended to the existing file.

### Log Files

- **Conversion log**: Details of PCAP to HC22000 conversion
- **Hashcat log**: Hashcat execution details and errors
- **Main log**: Complete script execution log

### Summary Report

Generated after each run with:
- Configuration details
- Statistics (files processed, converted, cracked)
- List of all cracked networks
- Paths to log files

## Troubleshooting

### Common Issues

#### 1. SSH Connection Failed
```bash
# Test SSH connection
ssh pi@raspberrypi.local

# Check SSH key permissions
chmod 600 ~/.ssh/pwnagotchi_rsa
chmod 644 ~/.ssh/pwnagotchi_rsa.pub
```

#### 2. hcxpcapngtool Not Found
```bash
# Check if installed
which hcxpcapngtool

# Reinstall if needed
# Follow installation steps above
```

#### 3. No PCAP Files Found
```bash
# Check Pi handshakes directory
ssh pi@raspberrypi.local "ls -la /home/pi/handshakes/"

# Verify Pwnagotchi configuration
ssh pi@raspberrypi.local "grep handshakes /etc/pwnagotchi/config.toml"
```

#### 4. Hashcat Errors
```bash
# Check hashcat installation
hashcat --version

# Test with benchmark
hashcat -b

# Check GPU drivers (if using GPU acceleration)
hashcat -I
```

### Debug Mode

Run with bash debug mode:
```bash
bash -x ./wpa2crack.sh
```

## Security Notes

⚠️ **Important Security Considerations:**

1. **Legal Use Only**: Only crack handshakes from networks you own or have explicit permission to test
2. **Secure Storage**: Keep cracked passwords secure and delete when no longer needed
3. **SSH Keys**: Protect your SSH private keys and use strong passphrases
4. **Wordlists**: Large wordlists can contain offensive content - review before use
5. **Network Security**: This tool demonstrates why strong, unique passwords are essential

## Performance Tips

1. **Use GPU Acceleration**: 
   - `GPU_MODE=1` - Use GPU only (faster than CPU)
   - `GPU_MODE=2` - Use GPU with high performance workload (fastest)
   - Requires CUDA (NVIDIA) or OpenCL (AMD) drivers
2. **Optimize Attack Strategy**:
   - Start with wordlist attacks for common passwords
   - Use targeted brute force patterns based on password policies
   - Try digit-only patterns for router default passwords
3. **Optimize Wordlists**: Smaller, targeted wordlists crack faster than huge generic ones
4. **Batch Processing**: The combined.hc22000 file allows efficient batch cracking
5. **Rule-Based Attacks**: Consider using hashcat rules for better coverage

## Advanced Usage

### Using Local PCAP Files

Instead of downloading from a Raspberry Pi, you can process local PCAP files:

```bash
# Process PCAP files from a local directory
SOURCE_MODE=local LOCAL_PCAP_DIR=/path/to/pcaps ./wpa2crack.sh

# Example with captures from another tool
SOURCE_MODE=local LOCAL_PCAP_DIR=~/airodump-captures ./wpa2crack.sh

# Local files with GPU acceleration
SOURCE_MODE=local LOCAL_PCAP_DIR=./handshakes GPU_MODE=2 ./wpa2crack.sh
```

This is useful when:
- You've already downloaded PCAP files
- You're using captures from other tools (airodump-ng, etc.)
- You want to re-process files without downloading again
- You're testing or developing

### Custom Hashcat Options

Edit the script to add custom hashcat options:

```bash
# Add rules
hashcat -m 22000 -a 0 -r /path/to/rules/best64.rule ...

# Use GPU only
hashcat -m 22000 -a 0 -d 1 ...

# Increase workload
hashcat -m 22000 -a 0 -w 3 ...
```

### Integration with Pwnagotchi

For automatic processing, create a cron job:

```bash
# Run every hour
0 * * * * /path/to/wpa2crack.sh >> /var/log/wpa2crack.log 2>&1
```

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the GPL-3.0 License - see the LICENSE file for details.

## Acknowledgments

- Inspired by [Pwnagotchi-Converter](https://github.com/Floo33R/Pwnagotchi-Converter)
- Uses [hashcat](https://hashcat.net/hashcat/) for password cracking
- Built for the [Pwnagotchi](https://pwnagotchi.ai/) community

## Disclaimer

This tool is for educational and authorized testing purposes only. Users are responsible for complying with applicable laws and regulations. The authors assume no liability for misuse or damage caused by this program.

---

**Remember**: The best defense against these attacks is using strong, unique passwords and keeping your devices updated!