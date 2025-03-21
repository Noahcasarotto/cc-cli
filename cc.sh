#!/bin/bash

# CC CLI - Easy command line interface for CC models
# Author: Noah Casarotto-Dinning
# Created with assistance from AI

VERSION="0.2.0"
MODELS=("cc-r1:1.5b" "cc-r1:8b" "cc-r1:14b" "cc-r1:32b" "cc-r1:70b")
ALTERNATIVE_MODELS=("phi" "mistral" "gemma:2b" "llama3:8b" "qwen:4b")
DEFAULT_MODEL="cc-r1:8b"
CONFIG_DIR="$HOME/.cc-cli"
CONFIG_FILE="$CONFIG_DIR/config"
FIRST_RUN_FILE="$CONFIG_DIR/first_run_complete"

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_banner() {
    echo -e "${BLUE}"
    echo "   _____  _____ "
    echo "  / ____|/ ____|"
    echo " | |    | |     "
    echo " | |    | |     "
    echo " | |____| |____ "
    echo "  \_____|\_____| "
    echo -e "${CYAN}Version: $VERSION${NC}"
    echo
}

check_dependencies() {
    echo -e "${YELLOW}Checking dependencies...${NC}"
    
    # Check if Homebrew is installed
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if ! command -v brew &> /dev/null; then
            echo -e "${RED}Homebrew is not installed. Installing...${NC}"
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
    fi

    # Check if Ollama is installed
    if ! command -v ollama &> /dev/null; then
        echo -e "${RED}Ollama is not installed. Installing...${NC}"
        
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install ollama
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            curl -fsSL https://ollama.com/install.sh | sh
        else
            echo -e "${RED}Unsupported operating system. Please install Ollama manually from https://ollama.com${NC}"
            exit 1
        fi
        
        # Start Ollama service
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew services start ollama
            sleep 2  # Give Ollama time to start
        fi
    fi
    
    echo -e "${GREEN}All dependencies are installed.${NC}"
}

ensure_config_dir() {
    if [ ! -d "$CONFIG_DIR" ]; then
        mkdir -p "$CONFIG_DIR"
    fi
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "default_model=$DEFAULT_MODEL" > "$CONFIG_FILE"
        echo "verbose=false" >> "$CONFIG_FILE"
    fi
}

load_config() {
    ensure_config_dir
    source "$CONFIG_FILE"
}

save_config() {
    ensure_config_dir
    echo "default_model=$default_model" > "$CONFIG_FILE"
    echo "verbose=$verbose" >> "$CONFIG_FILE"
}

pull_model() {
    model=$1
    if [ -z "$model" ]; then
        model=$default_model
    fi
    
    echo -e "${YELLOW}Downloading model: $model${NC}"
    ollama pull $model
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Model downloaded successfully.${NC}"
    else
        echo -e "${RED}Failed to download model.${NC}"
        exit 1
    fi
}

run_model() {
    model=$1
    if [ -z "$model" ]; then
        model=$default_model
    fi
    
    shift
    
    echo -e "${GREEN}Starting model $model...${NC}"
    if [ "$verbose" = "true" ]; then
        ollama run $model --verbose "$@"
    else
        ollama run $model "$@"
    fi
}

set_default_model() {
    model=$1
    
    # Validate model name
    valid_model=false
    for m in "${MODELS[@]}" "${ALTERNATIVE_MODELS[@]}"; do
        if [ "$m" = "$model" ]; then
            valid_model=true
            break
        fi
    done
    
    if [ "$valid_model" = false ]; then
        echo -e "${RED}Invalid model name: $model${NC}"
        echo -e "${YELLOW}Available CC models: ${MODELS[*]}${NC}"
        echo -e "${YELLOW}Alternative recommended models: ${ALTERNATIVE_MODELS[*]}${NC}"
        return 1
    fi
    
    default_model=$model
    save_config
    echo -e "${GREEN}Default model set to: $default_model${NC}"
}

get_installed_models() {
    installed_models=$(ollama list | awk '{print $1}' | tail -n +2)
    echo "$installed_models"
}

list_models() {
    echo -e "${CYAN}Available CC models:${NC}"
    for model in "${MODELS[@]}"; do
        if [ "$model" = "$default_model" ]; then
            echo -e "  ${GREEN}* $model (default)${NC}"
        else
            echo -e "  $model"
        fi
    done
    
    echo -e "\n${CYAN}Recommended alternative models (better for limited hardware):${NC}"
    for model in "${ALTERNATIVE_MODELS[@]}"; do
        if [ "$model" = "$default_model" ]; then
            echo -e "  ${GREEN}* $model (default)${NC}"
        else
            echo -e "  $model"
        fi
    done
    
    echo -e "\n${CYAN}Currently installed models:${NC}"
    ollama list
}

recommend_models() {
    echo -e "${CYAN}Recommended Models for Limited Hardware:${NC}"
    echo -e "  ${GREEN}phi${NC} - Microsoft's 2.7B model, small but powerful (~1.7GB, needs ~10GB RAM)"
    echo -e "  ${GREEN}mistral${NC} - 7B model with excellent performance (~4.1GB, needs ~14GB RAM)"
    echo -e "  ${GREEN}gemma:2b${NC} - Google's 2B model, good for basic tasks (~1.8GB, needs ~8GB RAM)"
    echo -e "  ${GREEN}llama3:8b${NC} - Meta's 8B model, very capable (~4.7GB, needs ~16GB RAM)"
    echo -e "  ${GREEN}qwen:4b${NC} - 4B model with good performance (~2.9GB, needs ~10GB RAM)"
    echo
    echo -e "To use these models:"
    echo -e "  ${YELLOW}cc pull phi${NC}                # Download phi model"
    echo -e "  ${YELLOW}cc set-default phi${NC}         # Set as default"
    echo -e "  ${YELLOW}cc run phi \"Your prompt\"${NC}   # Run with a specific prompt"
}

detect_hardware() {
    # Get total RAM
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        total_ram=$(sysctl hw.memsize | awk '{print $2/1024/1024/1024 " GB"}')
        cpu_info=$(sysctl -n machdep.cpu.brand_string)
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        total_ram=$(free -h | awk '/^Mem:/ {print $2}')
        cpu_info=$(grep "model name" /proc/cpuinfo | head -n 1 | cut -d ":" -f 2 | sed 's/^[ \t]*//')
    else
        total_ram="Unknown"
        cpu_info="Unknown"
    fi
    
    # Check if NVIDIA GPU is present
    if command -v nvidia-smi &> /dev/null; then
        gpu_info=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n 1)
        has_gpu=true
    elif [[ "$OSTYPE" == "darwin"* ]] && [[ "$cpu_info" == *"Apple"* ]]; then
        gpu_info="Apple Silicon GPU"
        has_gpu=true
    else
        gpu_info="No dedicated GPU detected"
        has_gpu=false
    fi
    
    # Extract RAM GB
    ram_gb=$(echo $total_ram | grep -o -E '[0-9]+')
    if [[ -z "$ram_gb" ]]; then
        ram_gb=0
    fi
    
    # Return hardware info
    echo "cpu_info=\"$cpu_info\""
    echo "gpu_info=\"$gpu_info\""
    echo "ram_gb=$ram_gb"
    echo "has_gpu=$has_gpu"
}

recommend_best_model() {
    # Source hardware info
    eval "$(detect_hardware)"
    
    # Default model to recommend
    recommended_model="phi"
    
    # Recommend based on RAM
    if (( ram_gb >= 32 )); then
        if [[ "$has_gpu" == true ]]; then
            recommended_model="mistral"
        else
            recommended_model="llama3:8b"
        fi
    elif (( ram_gb >= 16 )); then
        if [[ "$has_gpu" == true ]]; then
            recommended_model="llama3:8b"
        else
            recommended_model="mistral"
        fi
    elif (( ram_gb >= 12 )); then
        recommended_model="qwen:4b"
    elif (( ram_gb >= 8 )); then
        recommended_model="phi"
    else
        recommended_model="gemma:2b"
    fi
    
    # Special case for Apple Silicon
    if [[ "$gpu_info" == "Apple Silicon GPU" ]]; then
        if (( ram_gb >= 16 )); then
            recommended_model="llama3:8b"
        elif (( ram_gb >= 8 )); then
            recommended_model="phi"
        else
            recommended_model="gemma:2b"
        fi
    fi
    
    echo "$recommended_model"
}

check_hardware() {
    echo -e "${CYAN}Checking system hardware...${NC}"
    
    # Source hardware info
    eval "$(detect_hardware)"
    
    echo -e "CPU: ${YELLOW}$cpu_info${NC}"
    echo -e "Total RAM: ${YELLOW}$total_ram${NC}"
    echo -e "GPU: ${YELLOW}$gpu_info${NC}"
    
    echo
    echo -e "${CYAN}Based on your hardware:${NC}"
    
    # Make model recommendations based on available RAM
    if (( ram_gb >= 32 )); then
        echo -e "  You can run models up to: ${GREEN}cc-r1:14b, llama3:8b, mistral${NC}"
    elif (( ram_gb >= 16 )); then
        echo -e "  You can run models up to: ${GREEN}cc-r1:8b, llama3:8b, mistral${NC}"
    elif (( ram_gb >= 12 )); then
        echo -e "  Recommended models: ${GREEN}mistral, qwen:4b${NC}"
    elif (( ram_gb >= 8 )); then
        echo -e "  Recommended models: ${GREEN}phi, gemma:2b, qwen:4b${NC}"
    else
        echo -e "  ${RED}Your system has limited RAM. Consider using phi or gemma:2b models with caution.${NC}"
    fi
    
    # Show current best recommendation
    best_model=$(recommend_best_model)
    echo -e "\n${CYAN}Best model for your hardware:${NC} ${GREEN}$best_model${NC}"
}

perform_first_run_setup() {
    print_banner
    echo -e "${CYAN}Welcome to CC CLI!${NC}"
    echo -e "This appears to be your first time running this tool."
    echo -e "Let's set up the best AI model for your hardware.\n"
    
    # Check dependencies
    check_dependencies
    
    # Analyze hardware
    echo -e "\n${CYAN}Analyzing your hardware...${NC}"
    eval "$(detect_hardware)"
    echo -e "CPU: ${YELLOW}$cpu_info${NC}"
    echo -e "Total RAM: ${YELLOW}$total_ram${NC}"
    echo -e "GPU: ${YELLOW}$gpu_info${NC}"
    
    # Get best model recommendation
    best_model=$(recommend_best_model)
    
    echo -e "\n${CYAN}Based on your hardware, the recommended model is:${NC} ${GREEN}$best_model${NC}"
    
    # Prompt user for confirmation
    read -p "Would you like to download and set this model as default? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Downloading and setting up $best_model...${NC}"
        pull_model "$best_model"
        set_default_model "$best_model"
        echo -e "\n${GREEN}Setup complete!${NC}"
        echo -e "You can now use the model by running: ${CYAN}cc run \"Your prompt here\"${NC}"
    else
        echo -e "${YELLOW}Skipping automatic model download.${NC}"
        echo -e "You can manually download models later with: ${CYAN}cc pull <model>${NC}"
    fi
    
    # Mark first run as complete
    touch "$FIRST_RUN_FILE"
    
    echo -e "\n${CYAN}Setup completed. Type 'cc help' to see all available commands.${NC}"
}

# Check if this is the first run
check_first_run() {
    if [ ! -f "$FIRST_RUN_FILE" ]; then
        perform_first_run_setup
    fi
}

show_help() {
    echo -e "${CYAN}Usage:${NC}"
    echo "  cc [command] [options]"
    echo
    echo -e "${CYAN}Commands:${NC}"
    echo "  run [model] [prompt]   Run a model with the given prompt"
    echo "  install                Install or update requirements"
    echo "  pull [model]           Download a model"
    echo "  list                   List available models"
    echo "  recommend              Recommend best model for your system"
    echo "  hardware               Check your system hardware"
    echo "  setup                  Run first-time setup again"
    echo "  set-default [model]    Set default model"
    echo "  login                  Authenticate with cloud providers (GCP, AWS, Azure)"
    echo "  verbose [on|off]       Enable or disable verbose mode"
    echo "  version                Show version"
    echo "  help                   Show this help message"
    echo
    echo -e "${CYAN}Models:${NC}"
    echo "  cc-r1:1.5b, cc-r1:8b, cc-r1:14b, cc-r1:32b, cc-r1:70b"
    echo "  phi, mistral, gemma:2b, llama3:8b, qwen:4b"
    echo
    echo -e "${CYAN}Examples:${NC}"
    echo "  cc run \"What is the capital of France?\""
    echo "  cc run mistral \"Write me a poem about clouds.\""
    echo "  cc pull phi"
    echo "  cc recommend"
    echo "  cc login --gcp"
}

# Initialize
load_config

# Process command line arguments
case "$1" in
    install)
        print_banner
        check_dependencies
        pull_model "$2"
        ;;
    run)
        # Check if this is the first run
        check_first_run
        
        shift
        if [[ "$1" == cc-r1:* || " ${ALTERNATIVE_MODELS[@]} " =~ " $1 " ]]; then
            model=$1
            shift
            run_model "$model" "$@"
        else
            run_model "" "$@"
        fi
        ;;
    pull)
        pull_model "$2"
        ;;
    list)
        list_models
        ;;
    recommend)
        recommend_models
        ;;
    hardware)
        check_hardware
        ;;
    setup)
        # Force run the first-time setup again
        rm -f "$FIRST_RUN_FILE"
        perform_first_run_setup
        ;;
    login)
        # Run the cloud login script with any passed arguments
        shift
        "$(dirname "$0")/cc-login.sh" "$@"
        ;;
    set-default)
        set_default_model "$2"
        ;;
    verbose)
        if [ "$2" = "on" ]; then
            verbose=true
            save_config
            echo -e "${GREEN}Verbose mode enabled.${NC}"
        elif [ "$2" = "off" ]; then
            verbose=false
            save_config
            echo -e "${GREEN}Verbose mode disabled.${NC}"
        else
            echo -e "${RED}Invalid option. Use 'on' or 'off'.${NC}"
        fi
        ;;
    version)
        print_banner
        ;;
    help|"")
        # Check if this is the first run
        check_first_run
        
        show_help
        ;;
    *)
        # Check if this is the first run
        check_first_run
        
        echo -e "${RED}Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac

exit 0 