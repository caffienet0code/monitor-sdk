#!/usr/bin/env python3
"""
Bridge between macOS native monitor and Unified Backend API
Captures OS clicks and forwards to API server
"""

import subprocess
import re
import sys
import requests
import time
import os
from datetime import datetime

# Load API URL from config.env or use default
def load_config():
    config_file = os.path.join(os.path.dirname(__file__), 'config.env')
    if os.path.exists(config_file):
        with open(config_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line.startswith('API_URL='):
                    return line.split('=', 1)[1].strip()
    return 'http://localhost:8000'

BASE_API_URL = load_config()
SDK_API_URL = f'{BASE_API_URL}/api/click-detection/events/os'

def parse_log_line(line):
    """Parse OS monitor log line to extract click data"""
    # Looking for: [OS Monitor] Click detected: x=100.0, y=200.0, button=0, time=1234.567
    match = re.search(r'x=([\d.]+), y=([\d.]+), button=(\d+), time=([\d.]+)', line)
    if match:
        return {
            'x': float(match.group(1)),
            'y': float(match.group(2)),
            'button': int(match.group(3)),
            'timestamp': float(match.group(4))
        }
    return None

def send_to_api(click_data):
    """Send OS click to SDK API"""
    try:
        response = requests.post(SDK_API_URL, json=click_data, timeout=5)
        if response.status_code == 200:
            print(f"✓ Forwarded to SDK: x={click_data['x']:.1f}, y={click_data['y']:.1f}")
        else:
            print(f"✗ API error: {response.status_code}")
    except Exception as e:
        print(f"✗ Failed to send to API: {e}")

def main():
    print("🔗 OS Monitor Bridge")
    print("=" * 50)
    print("Forwarding OS clicks to SDK API at", SDK_API_URL)
    print("Starting native monitor...\n")

    # Check for BINARY_PATH environment variable first
    binary_path = os.environ.get('MONITOR_BINARY_PATH')

    if binary_path and os.path.exists(binary_path):
        print(f"Using binary from env: {binary_path}")
    else:
        # Fallback: Look in same directory as script
        script_dir = os.path.dirname(os.path.abspath(__file__))
        binary_name = None

        # Try different binary names
        for name in ['macos_monitor_universal', 'macos_monitor_test']:
            test_path = os.path.join(script_dir, name)
            if os.path.exists(test_path):
                binary_path = test_path
                binary_name = name
                break

        if not binary_name:
            print("❌ ERROR: Native monitor binary not found!")
            print("Expected: macos_monitor_universal or macos_monitor_test")
            print(f"Looking in: {script_dir}")
            sys.exit(1)

        print(f"Using binary: {binary_name}")

    # Start the native monitor as subprocess with unbuffered output
    process = subprocess.Popen(
        [binary_path],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=0,  # Unbuffered
        universal_newlines=True
    )

    try:
        for line in process.stdout:
            line = line.strip()
            print(f"[Monitor] {line}")

            # Parse and forward clicks
            click_data = parse_log_line(line)
            if click_data:
                send_to_api(click_data)

    except KeyboardInterrupt:
        print("\n\n👋 Stopping monitor...")
        process.terminate()
        sys.exit(0)

if __name__ == '__main__':
    main()
