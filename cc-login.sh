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
  echo "  --logout               Log out from all cloud providers"
  echo "  --logout-aws           Log out from AWS"
  echo "  --logout-azure         Log out from Azure"
  echo "  --logout-gcp           Log out from GCP"
  echo "  --help                 Show this help message"
  echo ""
  echo "Examples:"
  echo "  cc-login --all         Login to all cloud providers"
  echo "  cc-login --gcp         Login to GCP only"
  echo "  cc-login --status      Check login status"
  echo "  cc-login --logout      Log out from all providers"
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
    echo -e "${RED}Error: gcloud CLI not installed. Please install the Google Cloud SDK.${NC}"
    echo "Visit: https://cloud.google.com/sdk/docs/install"
    return 1
  fi
  
  # Check if already authenticated
  if gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
    echo -e "${GREEN}Already authenticated with GCP as $(gcloud auth list --filter=status:ACTIVE --format="value(account)")${NC}"
    update_auth_status "gcp" "true"
    return 0
  fi
  
  # Run the login command with browser-based authentication
  echo -e "${YELLOW}Launching Google Cloud web-based authentication...${NC}"
  echo -e "This will open a browser window where you can log in to your Google account."
  echo -e "After logging in through the browser, you'll be returned to the terminal."
  
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
    echo -e "${RED}Error: AWS CLI not installed. Please install the AWS CLI.${NC}"
    echo "Visit: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    return 1
  fi
  
  # Get AWS CLI version
  AWS_CLI_VERSION=$(aws --version 2>&1 | cut -d/ -f2 | cut -d' ' -f1)
  AWS_CLI_MAJOR_VERSION=$(echo $AWS_CLI_VERSION | cut -d. -f1)
  
  # Check if already authenticated
  if aws sts get-caller-identity >/dev/null 2>&1; then
    echo -e "${GREEN}Already authenticated with AWS as $(aws sts get-caller-identity --query 'Arn' --output text)${NC}"
    update_auth_status "aws" "true"
    return 0
  fi
  
  # Authentication options
  echo -e "${YELLOW}Would you like to:${NC}"
  echo -e "1) Browser-based login with AWS Console (recommended)"
  echo -e "2) Configure AWS CLI with access keys"
  echo -e "3) Skip AWS CLI configuration (browser login only)"
  read -p "Enter your choice (1, 2 or 3): " aws_option
  
  if [ "$aws_option" = "1" ]; then
    # Option 1: Browser-based login
    echo -e "${YELLOW}Opening AWS Console in your browser...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
      open "https://console.aws.amazon.com/"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
      xdg-open "https://console.aws.amazon.com/" &>/dev/null
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
      start "https://console.aws.amazon.com/"
    else
      echo -e "${YELLOW}Please open https://console.aws.amazon.com/ in your browser${NC}"
    fi
    
    echo -e "${YELLOW}After logging in to the AWS Console, you'll need to set up AWS CLI.${NC}"
    echo -e "${YELLOW}Please select option for AWS CLI configuration:${NC}"
    echo -e "1) Use IAM Identity Center (AWS SSO) - Recommended if your org uses SSO"
    echo -e "2) Use IAM Access Keys - Simpler option for individual accounts"
    read -p "Enter your choice (1 or 2): " cli_option
    
    if [ "$cli_option" = "1" ]; then
      # Option for AWS SSO
      echo -e "${YELLOW}Setting up AWS IAM Identity Center (SSO) configuration...${NC}"
      echo -e "${YELLOW}You will need the following information:${NC}"
      echo -e "${YELLOW}- SSO start URL (from your organization)${NC}"
      echo -e "${YELLOW}- SSO Region (e.g. us-east-1)${NC}"
      echo -e "${YELLOW}- Default output format (json recommended)${NC}"
      
      # Get SSO configuration details
      read -p "Enter your SSO start URL: " sso_start_url
      read -p "Enter your SSO region: " sso_region
      read -p "Enter default output format [json]: " output_format
      output_format=${output_format:-json}
      
      # Create ~/.aws/config if it doesn't exist
      mkdir -p ~/.aws
      touch ~/.aws/config
      
      # Check AWS CLI version for determining the approach
      if [ "$AWS_CLI_MAJOR_VERSION" = "1" ]; then
        # AWS CLI v1 doesn't have proper SSO commands - use a direct approach
        echo -e "${YELLOW}Using AWS CLI v1 with SSO configuration...${NC}"
        
        # Add role-based configuration
        echo -e "${YELLOW}You'll need to manually authorize in the browser and get temporary credentials.${NC}"
        echo -e "${YELLOW}Opening SSO start URL in browser...${NC}"
        
        # Open the SSO URL in browser
        if [[ "$OSTYPE" == "darwin"* ]]; then
          open "$sso_start_url"
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
          xdg-open "$sso_start_url" &>/dev/null
        elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
          start "$sso_start_url"
        else
          echo -e "${YELLOW}Please open $sso_start_url in your browser${NC}"
        fi
        
        echo -e "${YELLOW}After logging in through the browser:${NC}"
        echo -e "${YELLOW}1. Select the AWS account to use${NC}"
        echo -e "${YELLOW}2. Click on 'Command line or programmatic access'${NC}"
        echo -e "${YELLOW}3. Copy the credentials from Option 1 (temporary credentials)${NC}"
        
        # Let user manually enter credentials from the browser
        echo -e "${YELLOW}Enter the temporary AWS credentials from the browser:${NC}"
        read -p "AWS Access Key ID: " aws_access_key
        read -p "AWS Secret Access Key: " aws_secret_key
        read -p "AWS Session Token: " aws_session_token
        
        # Store credentials 
        aws configure set aws_access_key_id "$aws_access_key"
        aws configure set aws_secret_access_key "$aws_secret_key"
        aws configure set aws_session_token "$aws_session_token"
        aws configure set region "$sso_region"
        aws configure set output "$output_format"
        
        # Verify authentication
        if aws sts get-caller-identity >/dev/null 2>&1; then
          echo -e "${GREEN}Successfully authenticated with AWS using SSO temporary credentials${NC}"
          echo -e "${GREEN}Current identity: $(aws sts get-caller-identity --query 'Arn' --output text)${NC}"
          echo -e "${YELLOW}Note: These temporary credentials will expire. You'll need to repeat this process when they do.${NC}"
          update_auth_status "aws" "true"
          return 0
        else
          echo -e "${RED}Failed to authenticate with AWS. Invalid credentials.${NC}"
          update_auth_status "aws" "false"
          return 1
        fi
      else 
        # AWS CLI v2 approach using sso_start_url in config and aws sso login
        # Add SSO profile to config
        echo -e "\n[profile default]" >> ~/.aws/config
        echo "sso_start_url = $sso_start_url" >> ~/.aws/config
        echo "sso_region = $sso_region" >> ~/.aws/config
        echo "region = $sso_region" >> ~/.aws/config
        echo "output = $output_format" >> ~/.aws/config
        
        echo -e "${YELLOW}Configuration saved. Initiating SSO login...${NC}"
        
        # Attempt SSO login using the configured profile
        if aws sso login; then
          echo -e "${GREEN}Successfully authenticated with AWS SSO${NC}"
          update_auth_status "aws" "true"
          return 0
        else
          echo -e "${RED}Failed to authenticate with AWS SSO.${NC}"
          echo -e "${YELLOW}You may need to try again or use access keys.${NC}"
          update_auth_status "aws" "false"
          return 1
        fi
      fi
    elif [ "$cli_option" = "2" ]; then
      # Fallback to access keys
      aws_option="2"
    else
      echo -e "${RED}Invalid choice. Exiting AWS authentication.${NC}"
      return 1
    fi
  fi
  
  if [ "$aws_option" = "2" ]; then
    # Option 2: Configure with access keys
    echo -e "${YELLOW}Please enter your AWS access key credentials:${NC}"
    echo -e "${YELLOW}You can find or create these in the AWS Console under:${NC}"
    echo -e "${YELLOW}IAM → Users → Your User → Security credentials → Access keys${NC}"
    aws configure
    
    # Verify authentication
    if aws sts get-caller-identity >/dev/null 2>&1; then
      echo -e "${GREEN}Successfully authenticated with AWS as $(aws sts get-caller-identity --query 'Arn' --output text)${NC}"
      update_auth_status "aws" "true"
      return 0
    else
      echo -e "${RED}Failed to authenticate with AWS.${NC}"
      echo -e "${YELLOW}For help with AWS authentication, visit:${NC}"
      echo -e "${BLUE}https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html${NC}"
      update_auth_status "aws" "false"
      return 1
    fi
  elif [ "$aws_option" = "3" ]; then
    # Option 3: Skip AWS CLI configuration
    echo -e "${YELLOW}You've chosen to skip AWS CLI configuration.${NC}"
    echo -e "${YELLOW}Browser authentication acknowledged. Note that AWS CLI commands${NC}"
    echo -e "${YELLOW}will not work without credentials, but you can access AWS resources${NC}"
    echo -e "${YELLOW}through the AWS Console in your browser.${NC}"
    
    # Prompt to open the AWS Console
    echo -e "${YELLOW}Would you like to open the AWS Console in your browser? (y/n)${NC}"
    read -p "Open AWS Console? " open_console
    
    if [[ "$open_console" =~ ^[Yy] ]]; then
      echo -e "${YELLOW}Opening AWS Console...${NC}"
      # Try to open the AWS Console using the appropriate command for the OS
      if [[ "$OSTYPE" == "darwin"* ]]; then
        open "https://console.aws.amazon.com/"
      elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        xdg-open "https://console.aws.amazon.com/" &>/dev/null
      elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
        start "https://console.aws.amazon.com/"
      else
        echo -e "${YELLOW}Please open https://console.aws.amazon.com/ in your browser${NC}"
      fi
    fi
    
    # Mark AWS as authenticated in status file, but inform user about limitations
    update_auth_status "aws" "true"
    return 0
  else
    echo -e "${RED}Invalid choice. Exiting AWS authentication.${NC}"
    return 1
  fi
}

# Function to authenticate with Azure
authenticate_azure() {
  echo -e "${BLUE}Authenticating with Microsoft Azure...${NC}"
  
  if ! command_exists az; then
    echo -e "${RED}Error: Azure CLI not installed. Please install the Azure CLI.${NC}"
    echo "Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    return 1
  fi
  
  # Check if already authenticated
  if az account show >/dev/null 2>&1; then
    echo -e "${GREEN}Already authenticated with Azure as $(az account show --query 'user.name' -o tsv)${NC}"
    update_auth_status "azure" "true"
    return 0
  fi
  
  # Run the login command with browser-based authentication
  echo -e "${YELLOW}Launching Azure web-based authentication...${NC}"
  echo -e "This will open a browser window where you can log in to your Azure account."
  echo -e "After logging in through the browser, you'll be returned to the terminal."
  
  # Use --allow-no-subscriptions flag to handle accounts without any subscriptions
  if az login --allow-no-subscriptions; then
    # Try to get the user name
    USER_NAME=$(az account show --query 'user.name' -o tsv 2>/dev/null)
    if [ -n "$USER_NAME" ]; then
      echo -e "${GREEN}Successfully authenticated with Azure as $USER_NAME${NC}"
    else
      # Fallback if we can't get the username
      echo -e "${GREEN}Successfully authenticated with Azure${NC}"
    fi
    
    # Check for subscriptions
    subscription_count=$(az account list --query 'length([])' 2>/dev/null || echo "0")
    if [ "$subscription_count" -gt 0 ]; then
      echo -e "${YELLOW}Found $subscription_count subscription(s).${NC}"
      if [ "$subscription_count" -gt 1 ]; then
        echo -e "${YELLOW}Multiple subscriptions found. Please select a default:${NC}"
        az account list --query '[].{Name:name, ID:id, Default:isDefault}' -o table
        read -p "Enter subscription ID: " subscription_id
        az account set --subscription "$subscription_id"
      fi
    else
      echo -e "${YELLOW}No Azure subscriptions found for your account.${NC}"
      echo -e "${YELLOW}Note: You can still use some Azure services without a subscription.${NC}"
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

# Function to log out from AWS
logout_aws() {
  echo -e "${BLUE}Logging out from AWS...${NC}"
  
  if ! command_exists aws; then
    echo -e "${RED}Error: AWS CLI not installed.${NC}"
    return 1
  fi
  
  # Check if AWS CLI version 1 or 2
  AWS_CLI_VERSION=$(aws --version 2>&1 | cut -d/ -f2 | cut -d' ' -f1)
  AWS_CLI_MAJOR_VERSION=$(echo $AWS_CLI_VERSION | cut -d. -f1)
  
  # Try to log out
  if [ "$AWS_CLI_MAJOR_VERSION" = "2" ]; then
    # AWS CLI v2 has sso logout
    aws sso logout 2>/dev/null
  fi
  
  # Clear AWS credentials
  if [ -f ~/.aws/credentials ]; then
    echo -e "${YELLOW}Removing AWS credentials...${NC}"
    mv ~/.aws/credentials ~/.aws/credentials.bak
    touch ~/.aws/credentials
  fi
  
  # Clear AWS_* environment variables for this session
  unset AWS_ACCESS_KEY_ID
  unset AWS_SECRET_ACCESS_KEY
  unset AWS_SESSION_TOKEN
  unset AWS_DEFAULT_REGION
  
  echo -e "${GREEN}Successfully logged out from AWS.${NC}"
  update_auth_status "aws" "false"
  return 0
}

# Function to log out from Azure
logout_azure() {
  echo -e "${BLUE}Logging out from Azure...${NC}"
  
  if ! command_exists az; then
    echo -e "${RED}Error: Azure CLI not installed.${NC}"
    return 1
  fi
  
  # Try to log out
  if az logout; then
    echo -e "${GREEN}Successfully logged out from Azure.${NC}"
    update_auth_status "azure" "false"
    return 0
  else
    echo -e "${RED}Failed to log out from Azure.${NC}"
    return 1
  fi
}

# Function to log out from GCP
logout_gcp() {
  echo -e "${BLUE}Logging out from GCP...${NC}"
  
  if ! command_exists gcloud; then
    echo -e "${RED}Error: gcloud CLI not installed.${NC}"
    return 1
  fi
  
  # Try to log out (revoke credentials)
  if gcloud auth revoke --all; then
    echo -e "${GREEN}Successfully logged out from GCP.${NC}"
    update_auth_status "gcp" "false"
    return 0
  else
    echo -e "${RED}Failed to log out from GCP.${NC}"
    return 1
  fi
}

# Function to log out from all providers
logout_all() {
  echo -e "${BLUE}Logging out from all cloud providers...${NC}"
  
  logout_aws
  logout_azure
  logout_gcp
  
  echo -e "${GREEN}Logged out from all cloud providers.${NC}"
  return 0
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
        echo -e "${YELLOW}Authenticating with all available cloud providers...${NC}"
        authenticate_gcp
        # Make AWS optional
        echo -e "${YELLOW}Would you like to attempt AWS authentication? (y/n)${NC}"
        read -p "Authenticate with AWS? " do_aws
        if [[ "$do_aws" =~ ^[Yy] ]]; then
          authenticate_aws
        else
          echo -e "${YELLOW}Skipping AWS authentication.${NC}"
        fi
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
      --skip-aws)
        # New option to authenticate with everything except AWS
        echo -e "${YELLOW}Authenticating with all providers except AWS...${NC}"
        authenticate_gcp
        authenticate_azure
        exit 0
        ;;
      --logout)
        logout_all
        exit 0
        ;;
      --logout-aws)
        logout_aws
        exit 0
        ;;
      --logout-azure)
        logout_azure
        exit 0
        ;;
      --logout-gcp)
        logout_gcp
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
  echo "1) Login to all providers except AWS"
  echo "2) Login to GCP"
  echo "3) Login to AWS (optional)"
  echo "4) Login to Azure"
  echo "5) Logout from all providers"
  echo "6) Exit"
  
  read -p "Enter your choice (1-6): " choice
  
  case $choice in
    1)
      authenticate_gcp
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
      logout_all
      ;;
    6)
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