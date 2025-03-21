#!/bin/bash
# install_cloud_deps.sh - Install cloud provider CLIs and dependencies
#
# This script helps set up the necessary cloud provider CLIs for cc-login functionality

# Set up colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}CC CLI Cloud Dependencies Installer${NC}"
echo "This script will install the CLIs for GCP, AWS, and Azure"
echo

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Detect OS
detect_os() {
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "linux"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macos"
  else
    echo "unknown"
  fi
}

OS=$(detect_os)

# Check if Homebrew is installed (for macOS)
check_homebrew() {
  if ! command_exists brew; then
    echo -e "${YELLOW}Homebrew not found. Installing...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    return $?
  else
    echo -e "${GREEN}Homebrew is already installed.${NC}"
    return 0
  fi
}

# Install GCP CLI
install_gcp_cli() {
  echo -e "\n${BLUE}Installing Google Cloud SDK...${NC}"
  
  if command_exists gcloud; then
    echo -e "${GREEN}Google Cloud SDK is already installed.${NC}"
    return 0
  fi
  
  case $OS in
    macos)
      if check_homebrew; then
        echo -e "${YELLOW}Installing via Homebrew...${NC}"
        brew install --cask google-cloud-sdk
      else
        echo -e "${RED}Failed to install Homebrew. Cannot continue with GCP CLI installation.${NC}"
        return 1
      fi
      ;;
    linux)
      echo -e "${YELLOW}Installing via apt...${NC}"
      if command_exists apt; then
        echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
        curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
        sudo apt-get update
        sudo apt-get install -y google-cloud-sdk
      else
        echo -e "${RED}apt not found. Please install Google Cloud SDK manually.${NC}"
        echo "Visit: https://cloud.google.com/sdk/docs/install"
        return 1
      fi
      ;;
    *)
      echo -e "${RED}Unsupported OS. Please install Google Cloud SDK manually.${NC}"
      echo "Visit: https://cloud.google.com/sdk/docs/install"
      return 1
      ;;
  esac
  
  # Verify installation
  if command_exists gcloud; then
    echo -e "${GREEN}Google Cloud SDK installed successfully.${NC}"
    return 0
  else
    echo -e "${RED}Failed to install Google Cloud SDK.${NC}"
    return 1
  fi
}

# Install AWS CLI
install_aws_cli() {
  echo -e "\n${BLUE}Installing AWS CLI...${NC}"
  
  if command_exists aws; then
    echo -e "${GREEN}AWS CLI is already installed.${NC}"
    return 0
  fi
  
  case $OS in
    macos)
      if check_homebrew; then
        echo -e "${YELLOW}Installing via Homebrew...${NC}"
        brew install awscli
      else
        echo -e "${RED}Failed to install Homebrew. Cannot continue with AWS CLI installation.${NC}"
        return 1
      fi
      ;;
    linux)
      echo -e "${YELLOW}Installing via curl...${NC}"
      curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
      unzip -q awscliv2.zip
      sudo ./aws/install
      rm -rf aws awscliv2.zip
      ;;
    *)
      echo -e "${RED}Unsupported OS. Please install AWS CLI manually.${NC}"
      echo "Visit: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
      return 1
      ;;
  esac
  
  # Verify installation
  if command_exists aws; then
    echo -e "${GREEN}AWS CLI installed successfully.${NC}"
    return 0
  else
    echo -e "${RED}Failed to install AWS CLI.${NC}"
    return 1
  fi
}

# Install Azure CLI
install_azure_cli() {
  echo -e "\n${BLUE}Installing Azure CLI...${NC}"
  
  if command_exists az; then
    echo -e "${GREEN}Azure CLI is already installed.${NC}"
    return 0
  fi
  
  case $OS in
    macos)
      if check_homebrew; then
        echo -e "${YELLOW}Installing via Homebrew...${NC}"
        brew install azure-cli
      else
        echo -e "${RED}Failed to install Homebrew. Cannot continue with Azure CLI installation.${NC}"
        return 1
      fi
      ;;
    linux)
      echo -e "${YELLOW}Installing via script...${NC}"
      curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
      ;;
    *)
      echo -e "${RED}Unsupported OS. Please install Azure CLI manually.${NC}"
      echo "Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
      return 1
      ;;
  esac
  
  # Verify installation
  if command_exists az; then
    echo -e "${GREEN}Azure CLI installed successfully.${NC}"
    return 0
  else
    echo -e "${RED}Failed to install Azure CLI.${NC}"
    return 1
  fi
}

# Install jq (JSON processor)
install_jq() {
  echo -e "\n${BLUE}Installing jq (JSON processor)...${NC}"
  
  if command_exists jq; then
    echo -e "${GREEN}jq is already installed.${NC}"
    return 0
  fi
  
  case $OS in
    macos)
      if check_homebrew; then
        echo -e "${YELLOW}Installing via Homebrew...${NC}"
        brew install jq
      else
        echo -e "${RED}Failed to install Homebrew. Cannot continue with jq installation.${NC}"
        return 1
      fi
      ;;
    linux)
      echo -e "${YELLOW}Installing via apt...${NC}"
      if command_exists apt; then
        sudo apt-get update
        sudo apt-get install -y jq
      else
        echo -e "${RED}apt not found. Please install jq manually.${NC}"
        return 1
      fi
      ;;
    *)
      echo -e "${RED}Unsupported OS. Please install jq manually.${NC}"
      return 1
      ;;
  esac
  
  # Verify installation
  if command_exists jq; then
    echo -e "${GREEN}jq installed successfully.${NC}"
    return 0
  else
    echo -e "${RED}Failed to install jq.${NC}"
    return 1
  fi
}

# Main installation process
install_all() {
  # Start with jq as it's a dependency for our scripts
  install_jq
  
  # Prompt for each cloud provider
  echo
  read -p "Install Google Cloud SDK? (y/n): " install_gcp
  if [[ "$install_gcp" =~ ^[Yy]$ ]]; then
    install_gcp_cli
  fi
  
  echo
  read -p "Install AWS CLI? (y/n): " install_aws
  if [[ "$install_aws" =~ ^[Yy]$ ]]; then
    install_aws_cli
  fi
  
  echo
  read -p "Install Azure CLI? (y/n): " install_azure
  if [[ "$install_azure" =~ ^[Yy]$ ]]; then
    install_azure_cli
  fi
  
  echo
  echo -e "${GREEN}Installation complete.${NC}"
  echo "You can now use 'cc login' to authenticate with your cloud providers."
}

# Check command line arguments
if [[ "$1" == "--help" ]]; then
  echo "Usage: $0 [OPTIONS]"
  echo
  echo "Options:"
  echo "  --all     Install all cloud provider CLIs without prompting"
  echo "  --gcp     Install only Google Cloud SDK"
  echo "  --aws     Install only AWS CLI"
  echo "  --azure   Install only Azure CLI"
  echo "  --help    Show this help message"
  exit 0
elif [[ "$1" == "--all" ]]; then
  install_jq
  install_gcp_cli
  install_aws_cli
  install_azure_cli
elif [[ "$1" == "--gcp" ]]; then
  install_jq
  install_gcp_cli
elif [[ "$1" == "--aws" ]]; then
  install_jq
  install_aws_cli
elif [[ "$1" == "--azure" ]]; then
  install_jq
  install_azure_cli
else
  install_all
fi

exit 0 