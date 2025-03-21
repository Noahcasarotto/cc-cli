#!/bin/bash
# cc-login.sh - Cloud authentication script for CC CLI
#
# This script handles authentication with multiple cloud providers 
# including GCP, AWS, and Azure using a single command.

# Set up colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration directory
CONFIG_DIR="$HOME/.cc-cli"
CREDENTIALS_DIR="$HOME/.cc-cli/credentials"
AUTH_DIR="$HOME/.cc-cli/auth"

# Ensure directories exist
mkdir -p "$CONFIG_DIR"
mkdir -p "$CREDENTIALS_DIR"
mkdir -p "$AUTH_DIR"

# File to track which providers are authenticated
AUTH_STATUS_FILE="$AUTH_DIR/auth_status.json"

# Initialize auth status file if it doesn't exist
if [ ! -f "$AUTH_STATUS_FILE" ]; then
  cat > "$AUTH_STATUS_FILE" << EOL
{
  "gcp": false,
  "aws": false,
  "azure": false,
  "last_login": null
}
EOL
fi

# Function to show usage
show_usage() {
  echo -e "${BLUE}CC CLI Cloud Authentication${NC}"
  echo "Usage: cc-login [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --all                  Authenticate with all configured providers"
  echo "  --gcp                  Authenticate with Google Cloud Platform"
  echo "  --aws                  Authenticate with Amazon Web Services"
  echo "  --azure                Authenticate with Microsoft Azure"
  echo "  --status               Show authentication status for all providers"
  echo "  --help                 Show this help message"
  echo ""
  echo "Examples:"
  echo "  cc-login --all         Login to all cloud providers"
  echo "  cc-login --gcp         Login to GCP only"
  echo "  cc-login --status      Check login status"
}

# Function to update auth status
update_auth_status() {
  local provider=$1
  local status=$2
  
  # Use jq to update the status if available
  if command -v jq >/dev/null 2>&1; then
    jq --arg provider "$provider" --arg status "$status" \
       --arg date "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
       '.[$provider] = ($status == "true") | .last_login = $date' \
       "$AUTH_STATUS_FILE" > "${AUTH_STATUS_FILE}.tmp" && \
    mv "${AUTH_STATUS_FILE}.tmp" "$AUTH_STATUS_FILE"
  else
    # Simple alternative if jq is not available
    echo "{
      \"gcp\": $([ "$provider" = "gcp" ] && echo "$status" || grep -o '"gcp": [^,}]*' "$AUTH_STATUS_FILE" | cut -d: -f2),
      \"aws\": $([ "$provider" = "aws" ] && echo "$status" || grep -o '"aws": [^,}]*' "$AUTH_STATUS_FILE" | cut -d: -f2),
      \"azure\": $([ "$provider" = "azure" ] && echo "$status" || grep -o '"azure": [^,}]*' "$AUTH_STATUS_FILE" | cut -d: -f2),
      \"last_login\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"
    }" > "$AUTH_STATUS_FILE"
  fi
}

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to authenticate with GCP
authenticate_gcp() {
  echo -e "${BLUE}Authenticating with Google Cloud Platform...${NC}"
  
  if ! command_exists gcloud; then
    echo -e "${RED}Error: gcloud CLI not found. Please install the Google Cloud SDK.${NC}"
    echo "Visit: https://cloud.google.com/sdk/docs/install"
    return 1
  fi
  
  # Check if already authenticated
  if gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
    echo -e "${GREEN}Already authenticated with GCP as $(gcloud auth list --filter=status:ACTIVE --format="value(account)")${NC}"
    update_auth_status "gcp" "true"
    return 0
  fi
  
  # Run the login command
  if gcloud auth login; then
    echo -e "${GREEN}Successfully authenticated with GCP as $(gcloud auth list --filter=status:ACTIVE --format="value(account)")${NC}"
    
    # Set default project if none is set
    if [ -z "$(gcloud config get-value project 2>/dev/null)" ]; then
      echo -e "${YELLOW}No default project set. Select a default project:${NC}"
      gcloud projects list
      read -p "Enter project ID: " project_id
      gcloud config set project "$project_id"
    fi
    
    update_auth_status "gcp" "true"
    return 0
  else
    echo -e "${RED}Failed to authenticate with GCP.${NC}"
    update_auth_status "gcp" "false"
    return 1
  fi
}

# Function to authenticate with AWS
authenticate_aws() {
  echo -e "${BLUE}Authenticating with Amazon Web Services...${NC}"
  
  if ! command_exists aws; then
    echo -e "${RED}Error: AWS CLI not found. Please install the AWS CLI.${NC}"
    echo "Visit: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    return 1
  fi
  
  # Check if credentials exist and are valid
  if aws sts get-caller-identity >/dev/null 2>&1; then
    echo -e "${GREEN}Already authenticated with AWS as $(aws sts get-caller-identity --query 'Arn' --output text)${NC}"
    update_auth_status "aws" "true"
    return 0
  fi
  
  # Run the login command using AWS configure
  echo -e "${YELLOW}Please enter your AWS credentials:${NC}"
  aws configure
  
  # Verify authentication
  if aws sts get-caller-identity >/dev/null 2>&1; then
    echo -e "${GREEN}Successfully authenticated with AWS as $(aws sts get-caller-identity --query 'Arn' --output text)${NC}"
    update_auth_status "aws" "true"
    return 0
  else
    echo -e "${RED}Failed to authenticate with AWS.${NC}"
    update_auth_status "aws" "false"
    return 1
  fi
}

# Function to authenticate with Azure
authenticate_azure() {
  echo -e "${BLUE}Authenticating with Microsoft Azure...${NC}"
  
  if ! command_exists az; then
    echo -e "${RED}Error: Azure CLI not found. Please install the Azure CLI.${NC}"
    echo "Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    return 1
  fi
  
  # Check if already authenticated
  if az account show >/dev/null 2>&1; then
    echo -e "${GREEN}Already authenticated with Azure as $(az account show --query 'user.name' -o tsv)${NC}"
    update_auth_status "azure" "true"
    return 0
  fi
  
  # Run the login command
  if az login; then
    echo -e "${GREEN}Successfully authenticated with Azure as $(az account show --query 'user.name' -o tsv)${NC}"
    
    # Set default subscription if multiple are available
    subscription_count=$(az account list --query 'length([])')
    if [ "$subscription_count" -gt 1 ]; then
      echo -e "${YELLOW}Multiple subscriptions found. Please select a default:${NC}"
      az account list --query '[].{Name:name, ID:id, Default:isDefault}' -o table
      read -p "Enter subscription ID: " subscription_id
      az account set --subscription "$subscription_id"
    fi
    
    update_auth_status "azure" "true"
    return 0
  else
    echo -e "${RED}Failed to authenticate with Azure.${NC}"
    update_auth_status "azure" "false"
    return 1
  fi
}

# Function to show status
show_status() {
  echo -e "${BLUE}Cloud Provider Authentication Status:${NC}"
  
  if command_exists jq; then
    local gcp_status=$(jq -r '.gcp' "$AUTH_STATUS_FILE")
    local aws_status=$(jq -r '.aws' "$AUTH_STATUS_FILE")
    local azure_status=$(jq -r '.azure' "$AUTH_STATUS_FILE")
    local last_login=$(jq -r '.last_login' "$AUTH_STATUS_FILE")
  else
    local gcp_status=$(grep -o '"gcp": [^,}]*' "$AUTH_STATUS_FILE" | cut -d: -f2 | tr -d ' ')
    local aws_status=$(grep -o '"aws": [^,}]*' "$AUTH_STATUS_FILE" | cut -d: -f2 | tr -d ' ')
    local azure_status=$(grep -o '"azure": [^,}]*' "$AUTH_STATUS_FILE" | cut -d: -f2 | tr -d ' ')
    local last_login=$(grep -o '"last_login": "[^"]*"' "$AUTH_STATUS_FILE" | cut -d: -f2 | tr -d '"')
  fi
  
  # Convert boolean to status string
  gcp_status=$([ "$gcp_status" = "true" ] && echo "${GREEN}Authenticated${NC}" || echo "${RED}Not Authenticated${NC}")
  aws_status=$([ "$aws_status" = "true" ] && echo "${GREEN}Authenticated${NC}" || echo "${RED}Not Authenticated${NC}")
  azure_status=$([ "$azure_status" = "true" ] && echo "${GREEN}Authenticated${NC}" || echo "${RED}Not Authenticated${NC}")
  
  # Display status in a table format
  echo -e "┌────────────────────┬─────────────────────┐"
  echo -e "│ Provider           │ Status              │"
  echo -e "├────────────────────┼─────────────────────┤"
  echo -e "│ Google Cloud (GCP) │ $gcp_status         │"
  echo -e "│ AWS                │ $aws_status         │"
  echo -e "│ Azure              │ $azure_status       │"
  echo -e "└────────────────────┴─────────────────────┘"
  
  if [ "$last_login" != "null" ]; then
    echo -e "Last login: $last_login"
  fi
  
  # Check for active cloud provider CLIs
  echo -e "\n${BLUE}Cloud Provider CLI Status:${NC}"
  echo -e "┌────────────────────┬─────────────────────┐"
  echo -e "│ CLI                │ Status              │"
  echo -e "├────────────────────┼─────────────────────┤"
  if command_exists gcloud; then
    echo -e "│ gcloud (GCP)       │ ${GREEN}Installed${NC}         │"
  else
    echo -e "│ gcloud (GCP)       │ ${RED}Not Installed${NC}     │"
  fi
  
  if command_exists aws; then
    echo -e "│ aws                │ ${GREEN}Installed${NC}         │"
  else
    echo -e "│ aws                │ ${RED}Not Installed${NC}     │"
  fi
  
  if command_exists az; then
    echo -e "│ az (Azure)         │ ${GREEN}Installed${NC}         │"
  else
    echo -e "│ az (Azure)         │ ${RED}Not Installed${NC}     │"
  fi
  echo -e "└────────────────────┴─────────────────────┘"
}

# Main function
main() {
  # Parse command line arguments
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --help)
        show_usage
        exit 0
        ;;
      --all)
        authenticate_gcp
        authenticate_aws
        authenticate_azure
        exit 0
        ;;
      --gcp)
        authenticate_gcp
        exit 0
        ;;
      --aws)
        authenticate_aws
        exit 0
        ;;
      --azure)
        authenticate_azure
        exit 0
        ;;
      --status)
        show_status
        exit 0
        ;;
      *)
        echo -e "${RED}Error: Unknown option: $1${NC}"
        show_usage
        exit 1
        ;;
    esac
    shift
  done
  
  # Default behavior with no arguments: show status and prompt for action
  show_status
  
  echo -e "\n${BLUE}Choose an action:${NC}"
  echo "1) Login to all providers"
  echo "2) Login to GCP"
  echo "3) Login to AWS"
  echo "4) Login to Azure"
  echo "5) Exit"
  
  read -p "Enter your choice (1-5): " choice
  
  case $choice in
    1)
      authenticate_gcp
      authenticate_aws
      authenticate_azure
      ;;
    2)
      authenticate_gcp
      ;;
    3)
      authenticate_aws
      ;;
    4)
      authenticate_azure
      ;;
    5)
      exit 0
      ;;
    *)
      echo -e "${RED}Invalid choice. Exiting.${NC}"
      exit 1
      ;;
  esac
}

# Entry point
main "$@" 