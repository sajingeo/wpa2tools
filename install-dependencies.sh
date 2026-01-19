#!/bin/bash

# Installation script for WPA2 Handshake Cracker dependencies

echo "WPA2 Handshake Cracker - Dependency Installer"
echo "============================================="
echo ""

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    DISTRO=$(lsb_release -si 2>/dev/null || echo "Unknown")
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
else
    echo "Unsupported OS: $OSTYPE"
    exit 1
fi

echo "Detected OS: $OS"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install dependencies based on OS
if [ "$OS" == "linux" ]; then
    echo "Installing Linux dependencies..."
    
    # Update package list
    sudo apt update
    
    # Install required packages
    sudo apt install -y openssh-client hashcat xxd wget gcc make git libssl-dev libcurl4-openssl-dev pkg-config
    
elif [ "$OS" == "macos" ]; then
    echo "Installing macOS dependencies..."
    
    # Check if Homebrew is installed
    if ! command_exists brew; then
        echo "Homebrew not found. Please install Homebrew first:"
        echo "/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
    
    # Install hashcat
    brew install hashcat
fi

# Install hcxtools
echo ""
echo "Installing hcxtools..."

# Check if hcxpcapngtool is already installed
if command_exists hcxpcapngtool; then
    echo "hcxpcapngtool is already installed"
else
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Clone and build hcxtools
    echo "Cloning hcxtools repository..."
    git clone https://github.com/ZerBea/hcxtools.git
    cd hcxtools
    
    # Compile
    echo "Compiling hcxtools..."
    if [ "$OS" == "macos" ]; then
        # On macOS, some tools may fail to compile due to Linux-specific headers
        # We only need hcxpcapngtool, so we'll try to compile just what we need
        echo "Note: On macOS, some tools may fail to compile. This is normal."
        make hcxpcapngtool || true
        
        # Install manually if make install fails
        if [ -f hcxpcapngtool ]; then
            echo "Installing hcxpcapngtool..."
            sudo cp hcxpcapngtool /usr/local/bin/
            sudo chmod +x /usr/local/bin/hcxpcapngtool
        fi
    else
        # On Linux, compile everything
        make -j $(nproc)
        
        # Install to /usr/local/bin
        echo "Installing hcxtools..."
        sudo make install PREFIX=/usr/local
    fi
    
    # Clean up
    cd -
    rm -rf "$TEMP_DIR"
fi

# Download rockyou wordlist if not present
WORDLIST_DIR="$HOME/wordlist"

if [ ! -f "$WORDLIST_DIR/rockyou.txt" ]; then
    echo ""
    echo "Downloading rockyou.txt wordlist..."
    mkdir -p "$WORDLIST_DIR"
    cd "$WORDLIST_DIR"
    wget https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt
    cd -
fi

# Verify installations
echo ""
echo "Verifying installations..."
echo "========================="

MISSING=0

for cmd in ssh scp tar hcxpcapngtool hashcat xxd; do
    if command_exists "$cmd"; then
        echo "✓ $cmd installed"
    else
        echo "✗ $cmd NOT installed"
        MISSING=$((MISSING + 1))
    fi
done

# Check wordlist
if [ -f "$WORDLIST_DIR/rockyou.txt" ]; then
    echo "✓ rockyou.txt wordlist present"
else
    echo "✗ rockyou.txt wordlist NOT found"
    MISSING=$((MISSING + 1))
fi

echo ""
if [ $MISSING -eq 0 ]; then
    echo "All dependencies installed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Set up SSH keys for your Raspberry Pi (see README.md)"
    echo "2. Configure your Pi host in the script or use PI_HOST environment variable"
    echo "3. Run ./wpa2crack.sh to start cracking!"
else
    echo "Some dependencies failed to install. Please check the errors above."
    exit 1
fi