#!/bin/bash
# ContextFort Monitor - One-Command Installer
#
# Installation:
#   curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install.sh | bash
#
# Usage after install:
#   monitor          # Start monitoring
#   monitor stop     # Stop monitoring
#   monitor config   # Configure backend URL

set -e

# Configuration
INSTALL_DIR="$HOME/.contextfort"
GITHUB_RAW_BASE="https://raw.githubusercontent.com/caffienet0code/monitor-sdk/main"
BACKEND_URL="${CONTEXTFORT_BACKEND:-https://caffienet0code-agents-blocker-4hj7.vercel.app/api/sdk/click}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
cat << "EOF"
╔════════════════════════════════════════════════════════╗
║                                                        ║
║          ContextFort Monitor - Installation           ║
║                                                        ║
╚════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Detect if running as install or as monitor command
if [ "$(basename "$0")" = "monitor" ] || [ "$1" = "run" ]; then
    # Running as monitor command
    BINARY="$INSTALL_DIR/macos_monitor_universal"
    BRIDGE="$INSTALL_DIR/bridge.py"
    CONFIG="$INSTALL_DIR/config.txt"
    PID_FILE="$INSTALL_DIR/monitor.pid"

    if [ ! -f "$BINARY" ]; then
        echo -e "${RED}❌ ContextFort not installed!${NC}"
        echo "Run: curl -fsSL $GITHUB_RAW_BASE/install.sh | bash"
        exit 1
    fi

    # Handle commands
    case "$1" in
        stop)
            if [ -f "$PID_FILE" ]; then
                PID=$(cat "$PID_FILE")
                kill $PID 2>/dev/null || true
                pkill -f "macos_monitor_universal" 2>/dev/null || true
                pkill -f "contextfort.*bridge.py" 2>/dev/null || true
                rm -f "$PID_FILE"
                echo -e "${GREEN}✓ Monitor stopped${NC}"
            else
                echo -e "${YELLOW}⚠️  Monitor not running${NC}"
            fi
            exit 0
            ;;
        config)
            read -p "Enter backend URL: " NEW_URL
            echo "$NEW_URL" > "$CONFIG"
            echo -e "${GREEN}✓ Backend URL updated${NC}"
            exit 0
            ;;
        status)
            if [ -f "$PID_FILE" ]; then
                PID=$(cat "$PID_FILE")
                if ps -p $PID > /dev/null 2>&1; then
                    echo -e "${GREEN}✓ Monitor is running (PID: $PID)${NC}"
                else
                    echo -e "${YELLOW}⚠️  Stale PID file, monitor not running${NC}"
                    rm -f "$PID_FILE"
                fi
            else
                echo -e "${YELLOW}⚠️  Monitor not running${NC}"
            fi
            exit 0
            ;;
    esac

    # Start monitoring
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔════════════════════════════════════════════════════════╗
║       ContextFort Monitor - Developer Edition         ║
╚════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    # Check if already running
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p $PID > /dev/null 2>&1; then
            echo -e "${YELLOW}⚠️  Monitor already running (PID: $PID)${NC}"
            echo "Use 'monitor stop' to stop it first"
            exit 1
        fi
    fi

    # Load config
    if [ -f "$CONFIG" ]; then
        BACKEND_URL=$(cat "$CONFIG")
    fi

    echo -e "${BLUE}📍 Configuration:${NC}"
    echo -e "   Backend: ${YELLOW}$BACKEND_URL${NC}"
    echo ""
    echo -e "${YELLOW}💡 Note: If no clicks appear, grant Accessibility permission:${NC}"
    echo -e "   System Settings → Privacy & Security → Accessibility → Enable Terminal${NC}"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}🚀 Monitor Starting...${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}📊 Live Click Stream (Press Ctrl+C to stop):${NC}"
    echo ""

    # Set environment
    export MONITOR_BINARY_PATH="$BINARY"
    export SDK_API_URL="$BACKEND_URL"

    # Cleanup function
    cleanup() {
        echo ""
        echo -e "${YELLOW}🛑 Stopping monitor...${NC}"
        pkill -P $$ 2>/dev/null
        pkill -f "macos_monitor_universal" 2>/dev/null
        rm -f "$PID_FILE"
        echo -e "${GREEN}✓ Monitor stopped${NC}"
        exit 0
    }

    trap cleanup INT TERM

    # Run bridge
    cd "$INSTALL_DIR"
    python3 -u bridge.py &
    echo $! > "$PID_FILE"
    wait
    exit 0
fi

# Installation mode
echo -e "${BLUE}📦 Installing ContextFort Monitor...${NC}"
echo ""

# Create install directory
mkdir -p "$INSTALL_DIR"

# Download files from GitHub
echo -e "${BLUE}⬇️  Downloading files...${NC}"

# Download binary
if ! curl -fsSL "$GITHUB_RAW_BASE/macos_monitor_universal" -o "$INSTALL_DIR/macos_monitor_universal"; then
    echo -e "${RED}❌ Failed to download binary${NC}"
    echo "Make sure the GitHub repo is public and files are pushed"
    exit 1
fi
chmod +x "$INSTALL_DIR/macos_monitor_universal"

# Download bridge
if ! curl -fsSL "$GITHUB_RAW_BASE/bridge_fixed.py" -o "$INSTALL_DIR/bridge.py"; then
    echo -e "${RED}❌ Failed to download bridge${NC}"
    exit 1
fi

# Save default config
echo "$BACKEND_URL" > "$INSTALL_DIR/config.txt"

# Create monitor command
MONITOR_CMD="$INSTALL_DIR/monitor"
cp "$0" "$MONITOR_CMD" 2>/dev/null || curl -fsSL "$GITHUB_RAW_BASE/install.sh" -o "$MONITOR_CMD"
chmod +x "$MONITOR_CMD"

# Add to PATH if not already there
SHELL_RC=""
if [ -n "$ZSH_VERSION" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ]; then
    SHELL_RC="$HOME/.bashrc"
fi

if [ -n "$SHELL_RC" ]; then
    if ! grep -q "alias monitor=" "$SHELL_RC" 2>/dev/null; then
        echo "" >> "$SHELL_RC"
        echo "# ContextFort Monitor" >> "$SHELL_RC"
        echo "alias monitor='$MONITOR_CMD'" >> "$SHELL_RC"
        echo -e "${GREEN}✓ Added 'monitor' command to $SHELL_RC${NC}"
    fi
fi

echo ""
echo -e "${GREEN}✅ Installation complete!${NC}"
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Usage:${NC}"
echo ""
echo -e "  ${YELLOW}monitor${NC}          # Start monitoring"
echo -e "  ${YELLOW}monitor stop${NC}     # Stop monitoring"
echo -e "  ${YELLOW}monitor status${NC}   # Check if running"
echo -e "  ${YELLOW}monitor config${NC}   # Change backend URL"
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}⚠️  Restart your terminal, then run: ${GREEN}monitor${NC}"
echo ""

# Offer to start now
read -p "Start monitoring now? (y/n): " START_NOW
if [ "$START_NOW" = "y" ]; then
    exec "$MONITOR_CMD"
fi
