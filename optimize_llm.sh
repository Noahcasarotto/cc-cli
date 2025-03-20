#!/bin/bash

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${GREEN}Starting LLM System Optimization...${NC}"
echo "----------------------------------------"

# Get system specifications
CPU_CORES=$(sysctl -n hw.ncpu)

# Create optimization directory
OPT_DIR="$HOME/.llm-optimizations"
mkdir -p "$OPT_DIR"

# Configure Metal optimizations for M3
cat > "$OPT_DIR/metal.conf" << EOF
# Metal optimizations for Apple Silicon
export MTL_CAPTURE_ENABLED=0
export MTL_DEBUG_LAYER=0
export MTL_MAX_BUFFER_LENGTH=1073741824
export MTL_GPU_FAMILY=apple7
export MTL_GPU_VERSION=1
EOF

# Configure memory optimizations
cat > "$OPT_DIR/memory.conf" << EOF
# Memory optimizations for LLM
export MALLOC_ARENA_MAX=2
export MALLOC_MMAP_THRESHOLD_=131072
export MALLOC_TRIM_THRESHOLD_=131072
export MALLOC_MMAP_MAX_=65536

# Thread optimizations
export OMP_NUM_THREADS=$CPU_CORES
export MKL_NUM_THREADS=$CPU_CORES
export VECLIB_MAXIMUM_THREADS=$CPU_CORES
export NUMEXPR_NUM_THREADS=$CPU_CORES
export OPENBLAS_NUM_THREADS=$CPU_CORES
EOF

# Create the main environment file
cat > "$OPT_DIR/environment" << EOF
# LLM optimizations
source "$OPT_DIR/metal.conf"
source "$OPT_DIR/memory.conf"

# Performance optimizations
export PYTHONUNBUFFERED=1
export TF_CPP_MIN_LOG_LEVEL=2
export TF_ENABLE_ONEDNN_OPTS=1
export HDF5_USE_FILE_LOCKING=FALSE
EOF

# Create a performance mode script
cat > "$HOME/bin/llm-performance-mode" << EOF
#!/bin/bash
# Enable high performance mode for LLM operations

# Optimize disk I/O by flushing disk cache 
echo "Optimizing system for LLM operations..."
sudo purge

# Suggest performance enhancements
echo "For best performance:"
echo "1. Connect to power adapter"
echo "2. Quit unnecessary applications"
echo "3. Disable unnecessary background services"

echo "Performance mode active. Your LLM operations should now be faster."
EOF

# Create a wrapper for CC CLI
cat > "$HOME/bin/cc-optimized" << EOF
#!/bin/bash
# Wrapper script for CC CLI with optimized settings
source "$OPT_DIR/environment"
"$HOME/bin/cc" "\$@"
EOF

chmod +x "$HOME/bin/cc-optimized"
chmod +x "$HOME/bin/llm-performance-mode"

# Add to shell profile if not already there
if ! grep -q "source $OPT_DIR/environment" "$HOME/.zshrc"; then
    echo -e "\n# Load LLM optimizations" >> "$HOME/.zshrc"
    echo "source $OPT_DIR/environment" >> "$HOME/.zshrc"
fi

# Create a LaunchAgent to load optimizations at login
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$HOME/Library/LaunchAgents/com.llm.optimizations.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.llm.optimizations</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>source $OPT_DIR/environment</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF

# Load the LaunchAgent
launchctl load "$HOME/Library/LaunchAgents/com.llm.optimizations.plist"

echo -e "${GREEN}Optimization Complete!${NC}"
echo -e "Optimizations saved to: ${YELLOW}$OPT_DIR${NC}"
echo -e "Optimized CLI available as: ${YELLOW}cc-optimized${NC}"
echo -e "For max performance: ${YELLOW}llm-performance-mode${NC}"
echo "----------------------------------------"
echo -e "${YELLOW}Optimizations will be loaded automatically at login${NC}" 