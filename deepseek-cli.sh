#!/bin/bash

# DeepSeek CLI - Easy command line interface for DeepSeek models
# Author: Noah Casarotto-Dinning
# Created with assistance from AI

VERSION="0.1.0"
MODELS=("deepseek-r1:1.5b" "deepseek-r1:8b" "deepseek-r1:14b" "deepseek-r1:32b" "deepseek-r1:70b")
DEFAULT_MODEL="deepseek-r1:8b"
CONFIG_DIR="$HOME/.deepseek-cli"
CONFIG_FILE="$CONFIG_DIR/config"

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_banner() {
    echo -e "${BLUE}"
    echo "  _____                 _____           _      _____ _      _____  "
    echo " |  __ \               / ____|         | |    / ____| |    |_   _| "
    echo " | |  | | ___  ___ _ _| (___   ___  ___| | __| |    | |      | |   "
    echo " | |  | |/ _ \/ _ \ '_ \\___ \ / _ \/ _ \ |/ /| |    | |      | |   "
    echo " | |__| |  __/  __/ |_) |___) |  __/  __/   < | |____| |____ _| |_  "
    echo " |_____/ \___|\___| .__/_____/ \___|\___|_|\_\\\\_____|______|_____| "
    echo "                  | |                                               "
    echo "                  |_|                                               "
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
    
    echo -e "${YELLOW}Downloading DeepSeek model: $model${NC}"
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
    
    echo -e "${GREEN}Starting DeepSeek $model...${NC}"
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
    for m in "${MODELS[@]}"; do
        if [ "$m" = "$model" ]; then
            valid_model=true
            break
        fi
    done
    
    if [ "$valid_model" = false ]; then
        echo -e "${RED}Invalid model name: $model${NC}"
        echo -e "${YELLOW}Available models: ${MODELS[*]}${NC}"
        return 1
    fi
    
    default_model=$model
    save_config
    echo -e "${GREEN}Default model set to: $default_model${NC}"
}

list_models() {
    echo -e "${CYAN}Available DeepSeek models:${NC}"
    for model in "${MODELS[@]}"; do
        if [ "$model" = "$default_model" ]; then
            echo -e "  ${GREEN}* $model (default)${NC}"
        else
            echo -e "  $model"
        fi
    done
    
    echo -e "\n${CYAN}Installed models:${NC}"
    ollama list | grep deepseek
}

show_help() {
    print_banner
    echo -e "${CYAN}DeepSeek CLI - Easy command line interface for DeepSeek models${NC}"
    echo
    echo -e "Usage: $0 [command] [options]"
    echo
    echo -e "Commands:"
    echo -e "  ${GREEN}install${NC}            Install Ollama and download default DeepSeek model"
    echo -e "  ${GREEN}run${NC} [model] [args]  Run a DeepSeek model (default: $default_model)"
    echo -e "  ${GREEN}pull${NC} [model]        Download a DeepSeek model"
    echo -e "  ${GREEN}list${NC}                List available DeepSeek models"
    echo -e "  ${GREEN}set-default${NC} <model> Set the default DeepSeek model"
    echo -e "  ${GREEN}verbose${NC} <on|off>    Turn verbose mode on or off"
    echo -e "  ${GREEN}version${NC}             Show version information"
    echo -e "  ${GREEN}help${NC}                Show this help message"
    echo
    echo -e "Examples:"
    echo -e "  $0 install               # Install Ollama and download default model"
    echo -e "  $0 run                   # Run the default model"
    echo -e "  $0 run \"Tell me a joke\"  # Run with a prompt"
    echo -e "  $0 pull deepseek-r1:14b  # Download the 14B model"
    echo
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
        shift
        if [[ "$1" == deepseek-r1:* ]]; then
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
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac

exit 0 