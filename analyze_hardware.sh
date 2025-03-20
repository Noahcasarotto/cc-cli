#!/bin/bash

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Analyzing system hardware...${NC}"
echo "----------------------------------------"

# Get CPU information
echo -e "${YELLOW}CPU Information:${NC}"
CPU_MODEL=$(sysctl -n machdep.cpu.brand_string)
CPU_CORES=$(sysctl -n hw.ncpu)
echo "Model: $CPU_MODEL"
echo "Cores: $CPU_CORES"

# Get memory information
echo -e "\n${YELLOW}Memory Information:${NC}"
TOTAL_MEM=$(sysctl -n hw.memsize)
TOTAL_MEM_GB=$(echo "scale=2; $TOTAL_MEM/1024/1024/1024" | bc)
echo "Total Memory: ${TOTAL_MEM_GB}GB"

# Get disk information
echo -e "\n${YELLOW}Disk Information:${NC}"
DISK_INFO=$(df -h / | tail -n 1)
echo "Available Space: $(echo $DISK_INFO | awk '{print $4}')"

# Check for GPU
echo -e "\n${YELLOW}GPU Information:${NC}"
if command -v system_profiler &> /dev/null; then
    GPU_INFO=$(system_profiler SPDisplaysDataType | grep "Chipset Model:")
    if [ ! -z "$GPU_INFO" ]; then
        echo "GPU: $GPU_INFO"
    else
        echo "No dedicated GPU found"
    fi
fi

# Analyze and recommend model
echo -e "\n${GREEN}Model Recommendation:${NC}"
if (( $(echo "$TOTAL_MEM_GB < 8" | bc -l) )); then
    echo -e "${RED}Warning: Limited memory detected${NC}"
    echo "Recommended: Use smaller models (phi or deepseek-r1:1.5b)"
elif (( $(echo "$TOTAL_MEM_GB < 16" | bc -l) )); then
    echo "Recommended: Use medium-sized models (deepseek-r1:8b)"
else
    echo "Recommended: Can handle larger models (deepseek-r1:14b or larger)"
fi

# Performance optimization suggestions
echo -e "\n${GREEN}Performance Optimization Suggestions:${NC}"
if [ "$CPU_CORES" -lt 4 ]; then
    echo "- Consider using models with smaller context windows"
    echo "- Enable model quantization for better performance"
fi

if [ ! -z "$GPU_INFO" ]; then
    echo "- GPU detected: Consider enabling GPU acceleration"
else
    echo "- No GPU detected: Using CPU-only mode"
    echo "- Consider using quantized models for better performance"
fi

echo "----------------------------------------" 