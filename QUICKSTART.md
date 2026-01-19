# Quick Start Guide

## 1. Install Dependencies

Run the installation script:
```bash
./install-dependencies.sh
```

## 2. Set Up SSH Keys

Generate SSH keys for your Raspberry Pi:
```bash
# Generate key pair
ssh-keygen -t rsa -b 4096 -f ~/.ssh/pwnagotchi_rsa

# Copy to Pi (replace with your Pi's IP)
ssh-copy-id -i ~/.ssh/pwnagotchi_rsa.pub pi@192.168.1.100
```

## 3. Test SSH Connection

```bash
# Test connection (should not ask for password)
ssh -i ~/.ssh/pwnagotchi_rsa pi@192.168.1.100 "echo 'SSH working!'"
```

## 4. Run the Script

Basic usage:
```bash
./wpa2crack.sh
```

With custom Pi address:
```bash
PI_HOST="pi@192.168.1.100" ./wpa2crack.sh
```

## 5. Check Results

Look for cracked passwords in:
```
~/Downloads/handshakes/cracked/
```

Each cracked network will have a `.cracked` file with the SSID and password.

## Common Issues

### "No pcap files found"
- Make sure your Pwnagotchi is saving handshakes to `/home/pi/handshakes`
- Check Pwnagotchi config: `sudo nano /etc/pwnagotchi/config.toml`

### "SSH connection failed"
- Verify Pi IP address: `ping raspberrypi.local`
- Check SSH service: `ssh pi@raspberrypi.local`

### "hcxpcapngtool not found"
- Re-run the installation script
- Or manually install: see README.md

## Tips

1. **Faster Cracking**: Use a smaller, targeted wordlist for common passwords
2. **GPU Acceleration**: Install CUDA/OpenCL drivers for much faster cracking
3. **Custom Wordlists**: Create WiFi-specific wordlists with common router passwords

## Need Help?

Check the full README.md for detailed documentation and troubleshooting.