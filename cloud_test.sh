#!/bin/bash
# cloud_test.sh - Test script for cloud authentication functionality
#
# This script demonstrates how to use the cloud authentication system
# and verify that it's working correctly

# Set up colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration directory
CONFIG_DIR="$HOME/.cc-cli"
AUTH_DIR="$HOME/.cc-cli/auth"
AUTH_STATUS_FILE="$AUTH_DIR/auth_status.json"

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to check if we're authenticated with a provider
is_authenticated() {
  local provider=$1
  
  if [ ! -f "$AUTH_STATUS_FILE" ]; then
    return 1
  fi
  
  if command_exists jq; then
    local status=$(jq -r ".$provider" "$AUTH_STATUS_FILE")
    [ "$status" = "true" ] && return 0 || return 1
  else
    grep -q "\"$provider\": true" "$AUTH_STATUS_FILE" && return 0 || return 1
  fi
}

# Function to check GCP project info
check_gcp() {
  echo -e "${BLUE}Checking GCP Authentication...${NC}"
  
  if ! command_exists gcloud; then
    echo -e "${RED}Google Cloud SDK not installed.${NC}"
    return 1
  fi
  
  if ! is_authenticated "gcp"; then
    echo -e "${RED}Not authenticated with GCP.${NC}"
    echo "Run 'cc login --gcp' to authenticate."
    return 1
  fi
  
  echo -e "${GREEN}Authenticated with GCP.${NC}"
  
  # Get account info
  local account=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
  echo -e "Account: ${YELLOW}$account${NC}"
  
  # Get project info
  local project=$(gcloud config get-value project)
  if [ -n "$project" ]; then
    echo -e "Project: ${YELLOW}$project${NC}"
    
    # Get project details
    echo
    echo -e "${BLUE}Project Details:${NC}"
    gcloud projects describe "$project" --format="table[box](
      name,
      projectId,
      projectNumber,
      createTime.date('%Y-%m-%d %H:%M:%S %Z'),
      lifecycleState
    )"
    
    # Show available compute zones
    echo
    echo -e "${BLUE}Available Compute Zones:${NC}"
    gcloud compute zones list --filter="region:( us-central1 us-east1 us-west1 )" --format="table[box](
      name,
      region,
      status,
      category
    )"
  else
    echo -e "${YELLOW}No default project set.${NC}"
  fi
}

# Function to check AWS account info
check_aws() {
  echo -e "${BLUE}Checking AWS Authentication...${NC}"
  
  if ! command_exists aws; then
    echo -e "${RED}AWS CLI not installed.${NC}"
    return 1
  fi
  
  if ! is_authenticated "aws"; then
    echo -e "${RED}Not authenticated with AWS.${NC}"
    echo "Run 'cc login --aws' to authenticate."
    return 1
  fi
  
  echo -e "${GREEN}Authenticated with AWS.${NC}"
  
  # Get account info
  local account=$(aws sts get-caller-identity --query 'Arn' --output text)
  echo -e "Account: ${YELLOW}$account${NC}"
  
  # Get AWS regions
  echo
  echo -e "${BLUE}Available AWS Regions:${NC}"
  aws ec2 describe-regions --query "Regions[].{Name:RegionName,Endpoint:Endpoint}" --output table
}

# Function to check Azure account info
check_azure() {
  echo -e "${BLUE}Checking Azure Authentication...${NC}"
  
  if ! command_exists az; then
    echo -e "${RED}Azure CLI not installed.${NC}"
    return 1
  fi
  
  if ! is_authenticated "azure"; then
    echo -e "${RED}Not authenticated with Azure.${NC}"
    echo "Run 'cc login --azure' to authenticate."
    return 1
  fi
  
  echo -e "${GREEN}Authenticated with Azure.${NC}"
  
  # Get account info
  local account=$(az account show --query 'user.name' -o tsv)
  echo -e "Account: ${YELLOW}$account${NC}"
  
  # Get subscription info
  echo
  echo -e "${BLUE}Subscription Information:${NC}"
  az account show --output table
  
  # Get available locations
  echo
  echo -e "${BLUE}Available Azure Locations:${NC}"
  az account list-locations --query "[?metadata.regionType=='Physical'].{Name:name, DisplayName:displayName, Category:metadata.regionCategory}" --output table
}

# Function to show example code for cloud-based model running
show_example_usage() {
  echo -e "\n${BLUE}Example Usage for Cloud-Based Model Running:${NC}"
  echo -e "${YELLOW}This is a preview of how cloud integration will work in the future.${NC}"
  
  echo -e "\n${GREEN}Running a model on GCP:${NC}"
  echo -e "  cc run --cloud=gcp --machine=n1-standard-4 cc-r1:14b \"Tell me about cloud computing\""
  
  echo -e "\n${GREEN}Running a model on AWS:${NC}"
  echo -e "  cc run --cloud=aws --machine=g4dn.xlarge cc-r1:32b \"What are the benefits of GPUs?\""
  
  echo -e "\n${GREEN}Running a model on the cheapest available provider:${NC}"
  echo -e "  cc run --cloud=auto --model=cc-r1:8b \"Find me the most cost-effective solution\""
  
  echo -e "\n${GREEN}Setting up a persistent cloud instance:${NC}"
  echo -e "  cc cloud provision --provider=gcp --model=cc-r1:70b"
  echo -e "  cc cloud connect"
  echo -e "  cc cloud terminate"
}

# Main function
main() {
  echo -e "${BLUE}CC CLI Cloud Authentication Test${NC}"
  echo "This script verifies cloud provider authentication status"
  echo
  
  # Check if cc-login.sh exists
  if [ ! -f "$(dirname "$0")/cc-login.sh" ]; then
    echo -e "${RED}cc-login.sh not found. Make sure you're in the correct directory.${NC}"
    exit 1
  fi
  
  # Test each provider
  echo -e "${YELLOW}Testing cloud provider authentication:${NC}"
  echo
  
  check_gcp
  echo
  
  check_aws
  echo
  
  check_azure
  echo
  
  # Show example usage
  show_example_usage
}

# Run the main function
main "$@" 