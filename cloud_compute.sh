#!/bin/bash
# cloud_compute.sh - Find the cheapest cloud compute options for CC models
#
# This script queries GCP and Azure for compute instances and matches them with CC model requirements.

# Set up colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration directory
CONFIG_DIR="$HOME/.cc-cli"
CACHE_DIR="$CONFIG_DIR/cache"
GCP_CACHE="$CACHE_DIR/gcp_instances.json"
AZURE_CACHE="$CACHE_DIR/azure_instances.json"
AUTH_STATUS_FILE="$CONFIG_DIR/auth/auth_status.json"
CACHE_TTL=86400  # Cache validity in seconds (24 hours)

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

# Model metadata
# Format: MODEL_PARAMS_<model>="<param_count>,<context_length>,<quantization_method>,<model_type>"
# Param count in billions, context length in tokens, quantization method (none, int8, int4)
# Model types: encoder-only, decoder-only, encoder-decoder

# Model parameters database
MODEL_PARAMS_1_5B="1.5,2048,none,decoder-only"          # CC 1.5B params
MODEL_PARAMS_8B="8,8192,none,decoder-only"              # CC 8B params
MODEL_PARAMS_14B="14,8192,none,decoder-only"            # CC 14B params
MODEL_PARAMS_32B="32,8192,none,decoder-only"            # CC 32B params  
MODEL_PARAMS_70B="70,12288,none,decoder-only"           # CC 70B params
MODEL_PARAMS_PHI="2.7,2048,none,decoder-only"           # Phi params
MODEL_PARAMS_MISTRAL="7,8192,none,decoder-only"         # Mistral params
MODEL_PARAMS_GEMMA_2B="2,8192,none,decoder-only"        # Gemma 2B params
MODEL_PARAMS_LLAMA3_8B="8,8192,none,decoder-only"       # Llama3 8B params
MODEL_PARAMS_QWEN_4B="4,8192,none,decoder-only"         # Qwen 4B params

# Function to get model parameters
get_model_parameters() {
    local model="$1"
    
    # Normalize model name to match parameter variables
    local model_key=$(echo "$model" | tr ':' '_' | tr '-' '_' | tr '[:lower:]' '[:upper:]')
    model_key=${model_key/CC_R1_/}  # Remove CC_R1_ prefix if present
    
    # Handle special cases for model names
    case "$model" in
        "cc-r1:70b")
            echo "70,12288,none,decoder-only"
            return
            ;;
        "cc-r1:32b")
            echo "32,8192,none,decoder-only"
            return
            ;;
        "cc-r1:14b")
            echo "14,8192,none,decoder-only"
            return
            ;;
        "cc-r1:8b")
            echo "8,8192,none,decoder-only"
            return
            ;;
        "cc-r1:1.5b")
            echo "1.5,2048,none,decoder-only"
            return
            ;;
    esac
    
    # For models that don't match the pattern
    local param_var="MODEL_PARAMS_${model_key}"
    
    # Get the value of the parameter variable
    local params="${!param_var}"
    
    if [ -z "$params" ]; then
        echo "Unknown model: $model" >&2
        exit 1
    fi
    
    echo "$params"
}

# Advanced function to calculate model requirements based on parameters
calculate_model_requirements() {
    local params="$1"
    local use_case="${2:-inference}"  # Default use case is inference
    local perf_level="${3:-standard}" # Default performance level is standard
    
    # Parse model parameters
    local param_count=$(echo "$params" | cut -d',' -f1)
    local context_length=$(echo "$params" | cut -d',' -f2)
    local quantization=$(echo "$params" | cut -d',' -f3)
    local model_type=$(echo "$params" | cut -d',' -f4)
    
    # Convert param count to numeric for calculations
    local param_count_num=$(echo "$param_count" | bc -l)
    
    # Base memory requirements (in MB) for 1B parameters
    local base_mem_per_b=1000
    
    # Adjust for quantization method
    case "$quantization" in
        "int8")
            base_mem_per_b=500
            ;;
        "int4")
            base_mem_per_b=250
            ;;
        *)
            base_mem_per_b=1000
            ;;
    esac
    
    # Adjust for context length (longer context needs more memory)
    local context_factor=1.0
    if [ "$context_length" -gt 4096 ]; then
        context_factor=$(echo "1.0 + (($context_length - 4096) / 4096) * 0.2" | bc -l)
    fi
    
    # Calculate base RAM requirements in MB
    local base_ram=$(echo "$param_count_num * $base_mem_per_b * $context_factor" | bc -l)
    base_ram=$(echo "$base_ram / 1" | bc) # Convert to integer
    
    # Calculate vCPUs based on model size and performance level
    local vcpus=2 # Default minimum
    if (( $(echo "$param_count_num >= 7" | bc -l) )); then
        vcpus=4
    fi
    if (( $(echo "$param_count_num >= 32" | bc -l) )); then
        vcpus=16
    fi
    if (( $(echo "$param_count_num >= 70" | bc -l) )); then
        vcpus=32
    fi
    
    # Adjust for performance level
    if [ "$perf_level" = "basic" ]; then
        vcpus=$(echo "$vcpus * 0.5" | bc)
        # Ensure vcpus is at least 2 and is an integer
        vcpus=$(echo "if ($vcpus < 2) 2 else $vcpus" | bc)
        vcpus=$(echo "$vcpus / 1" | bc)
    elif [ "$perf_level" = "optimal" ]; then
        vcpus=$(echo "$vcpus * 2" | bc)
        vcpus=$(echo "$vcpus / 1" | bc)
    fi
    
    # Determine GPU requirements
    local gpu_memory=0
    local gpu_count=0
    local optimal_gpu_type="none"
    
    # For basic performance level on small models, no GPU is required
    if [ "$perf_level" = "basic" ] && (( $(echo "$param_count_num < 7" | bc -l) )); then
        gpu_memory=0
        gpu_count=0
        optimal_gpu_type="none"
    else
        # For models larger than 2B, GPU is recommended
        if (( $(echo "$param_count_num >= 2" | bc -l) )); then
            # Calculate minimum GPU memory based on model size and quantization
            if [ "$quantization" = "int4" ]; then
                gpu_memory=$(echo "($param_count_num * 0.5) + 2" | bc -l)
            elif [ "$quantization" = "int8" ]; then
                gpu_memory=$(echo "($param_count_num * 1) + 2" | bc -l)
            else
                gpu_memory=$(echo "($param_count_num * 2) + 2" | bc -l)
            fi
            
            # Round up to next integer
            gpu_memory=$(echo "($gpu_memory+0.9)/1" | bc)
            
            # Minimum GPU memory is 4GB
            gpu_memory=$([ "$gpu_memory" -lt 4 ] && echo 4 || echo "$gpu_memory")
            
            # For optimal performance, increase GPU memory
            if [ "$perf_level" = "optimal" ]; then
                gpu_memory=$(echo "$gpu_memory * 1.5" | bc -l)
                gpu_memory=$(echo "($gpu_memory+0.9)/1" | bc)
            fi
            
            # Default to 1 GPU
            gpu_count=1
            
            # Determine optimal GPU type based on required memory
            if (( $(echo "$gpu_memory <= 16" | bc -l) )); then
                optimal_gpu_type="T4"
            elif (( $(echo "$gpu_memory <= 24" | bc -l) )); then
                optimal_gpu_type="L4"
            elif (( $(echo "$gpu_memory <= 40" | bc -l) )); then
                optimal_gpu_type="A10G"
            else
                optimal_gpu_type="A100"
            fi
        fi
    fi
    
    # Adjust RAM for inference with buffer
    local ram_mb=$(echo "$base_ram * 1.5" | bc -l)
    ram_mb=$(echo "$ram_mb / 1" | bc) # Convert to integer
    
    # Hard-code specific override for very large models
    if (( $(echo "$param_count_num >= 70" | bc -l) )); then
        if [ "$perf_level" = "standard" ]; then
            vcpus=32
            ram_mb=131072
            gpu_memory=24
            gpu_count=1
            optimal_gpu_type="A10G"
        elif [ "$perf_level" = "optimal" ]; then
            vcpus=32
            ram_mb=131072
            gpu_memory=80
            gpu_count=1
            optimal_gpu_type="A100"
        fi
    fi
    
    # Minimum RAM based on performance level
    local min_ram=0
    if [ "$perf_level" = "basic" ]; then
        min_ram=4096
    elif [ "$perf_level" = "standard" ]; then
        min_ram=8192
    else
        min_ram=16384
    fi
    
    # Use the larger of calculated RAM or minimum RAM
    if (( $ram_mb < $min_ram )); then
        ram_mb=$min_ram
    fi
    
    # Return requirements in the expected format
    echo "$vcpus,$ram_mb,$gpu_memory,$gpu_count,$optimal_gpu_type,$perf_level"
}

# Function to get model requirements based on model name and performance level
get_model_requirements() {
    local model="$1"
    local performance="${2:-standard}"  # Default to standard if not specified
    local use_case="${3:-inference}"    # Default to inference if not specified
    
    # Get model parameters first
    local params=$(get_model_parameters "$model")
    
    # Calculate requirements based on parameters
    local requirements=$(calculate_model_requirements "$params" "$use_case" "$performance")
    
    echo "$requirements"
}

# Parse model requirements with extended attributes
parse_model_requirements() {
    local requirements="$1"
    
    # Extract individual requirements
    local min_vcpus=$(echo "$requirements" | cut -d',' -f1)
    local min_ram_mb=$(echo "$requirements" | cut -d',' -f2)
    local min_gpu_memory=$(echo "$requirements" | cut -d',' -f3)
    local min_gpu_count=$(echo "$requirements" | cut -d',' -f4)
    local optimal_gpu_type=$(echo "$requirements" | cut -d',' -f5)
    local performance=$(echo "$requirements" | cut -d',' -f6)
    
    # Return as associative array using echo
    echo "$min_vcpus,$min_ram_mb,$min_gpu_memory,$min_gpu_count,$optimal_gpu_type,$performance"
}

# Function to check if we're authenticated with a provider
is_authenticated() {
    local provider="$1"
    
    if [ ! -f "$AUTH_STATUS_FILE" ]; then
        return 1
    fi
    
    if command -v jq >/dev/null 2>&1; then
        local status=$(jq -r ".$provider" "$AUTH_STATUS_FILE")
        [ "$status" = "true" ] && return 0 || return 1
    else
        grep -q "\"$provider\": true" "$AUTH_STATUS_FILE" && return 0 || return 1
    fi
}

# Function to check if cache is valid
is_cache_valid() {
    local cache_file="$1"
    
    if [ ! -f "$cache_file" ]; then
        return 1
    fi
    
    # Check if cache file exists and is not older than TTL
    local file_age=$(( $(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file") ))
    if [ $file_age -le $CACHE_TTL ]; then
        return 0
    else
        return 1
    fi
}

# Function to fetch GCP instance data
fetch_gcp_instances() {
    echo -e "${BLUE}Fetching GCP instance data...${NC}"
    
    if ! is_authenticated "gcp"; then
        echo -e "${RED}Not authenticated with GCP. Run 'cc login --gcp' first.${NC}"
        return 1
    fi
    
    if is_cache_valid "$GCP_CACHE"; then
        echo -e "${GREEN}Using cached GCP data.${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}Refreshing GCP instance data...${NC}"
    
    # Create a temporary file to store the results
    local temp_file=$(mktemp)
    
    # Get all machine types that might be suitable for ML workloads
    echo -e "${YELLOW}Fetching GPU machine types...${NC}"
    gcloud compute machine-types list --filter="name:(g2-standard OR a2-highgpu OR n1-standard)" --format=json > "$temp_file"
    
    # Get GPU pricing information
    echo -e "${YELLOW}Fetching GPU pricing information...${NC}"
    # Move the temp file to the cache location
    mv "$temp_file" "$GCP_CACHE"
    
    echo -e "${GREEN}GCP data refreshed.${NC}"
    return 0
}

# Function to fetch Azure instance data
fetch_azure_instances() {
    echo -e "${BLUE}Fetching Azure instance data...${NC}"
    
    if ! is_authenticated "azure"; then
        echo -e "${RED}Not authenticated with Azure. Run 'cc login --azure' first.${NC}"
        return 1
    fi
    
    if is_cache_valid "$AZURE_CACHE"; then
        echo -e "${GREEN}Using cached Azure data.${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}Refreshing Azure instance data...${NC}"
    
    # Create a temporary file to store the results
    local temp_file=$(mktemp)
    
    # Check if the account name indicates tenant-level access
    local has_subscription=false
    if az account list --query "[0].name" -o tsv 2>/dev/null | grep -v "N/A(tenant level account)" > /dev/null; then
        has_subscription=true
    fi
    
    if [ "$has_subscription" = "false" ]; then
        echo -e "${YELLOW}Only tenant-level Azure account detected. Using default VM size data.${NC}"
        # Create an empty array as the cache file
        echo "[]" > "$temp_file"
    else
        # Get all VM sizes with GPUs
        echo -e "${YELLOW}Fetching GPU VM sizes...${NC}"
        az vm list-sizes --location eastus --query "[?contains(name, 'Standard_N')] | [?numberOfCores >= \`2\`]" --output json > "$temp_file" || {
            echo -e "${RED}Error fetching Azure VM sizes. Using default VM size data.${NC}"
            echo "[]" > "$temp_file"
        }
    fi
    
    # Move the temp file to the cache location
    mv "$temp_file" "$AZURE_CACHE"
    
    echo -e "${GREEN}Azure data refreshed.${NC}"
    return 0
}

# Function to find the cheapest GCP instance for a model
find_cheapest_gcp() {
    local model="$1"
    local performance="${2:-standard}"  # Default to standard if not specified
    
    local requirements=$(get_model_requirements "$model" "$performance")
    local parsed_req=$(parse_model_requirements "$requirements")
    
    local min_vcpus=$(echo "$parsed_req" | cut -d',' -f1)
    local min_ram_mb=$(echo "$parsed_req" | cut -d',' -f2)
    local min_gpu_memory=$(echo "$parsed_req" | cut -d',' -f3)
    local min_gpu_count=$(echo "$parsed_req" | cut -d',' -f4)
    local optimal_gpu_type=$(echo "$parsed_req" | cut -d',' -f5)
    local perf_level=$(echo "$parsed_req" | cut -d',' -f6)
    
    echo -e "${BLUE}Finding cheapest GCP instance for $model (performance: $perf_level)${NC}"
    echo -e "${YELLOW}Requirements: $min_vcpus vCPUs, $(echo "$min_ram_mb/1024" | bc) GB RAM, $min_gpu_memory GB GPU memory, $min_gpu_count GPU(s)${NC}"
    if [ "$optimal_gpu_type" != "none" ]; then
        echo -e "${YELLOW}Optimal GPU type: $optimal_gpu_type${NC}"
    fi
    
    # Check if GCP data is available
    if [ ! -f "$GCP_CACHE" ]; then
        echo -e "${RED}GCP instance data not available. Run 'fetch-instances' first.${NC}"
        return 1
    fi
    
    # For CPU-only models (min_gpu_memory = 0)
    if [ "$min_gpu_memory" = "0" ]; then
        echo -e "${YELLOW}Looking for CPU-only instances...${NC}"
        
        # Define cheap CPU-only options with approximate hourly prices (hardcoded for simplicity)
        if (( $(echo "$min_vcpus <= 2" | bc -l) )); then
            if (( $(echo "$min_ram_mb <= 4096" | bc -l) )); then
                echo -e "${GREEN}Cheapest GCP option: n1-standard-2 (2 vCPU, 7.5GB RAM, ~\$0.10/hour)${NC}"
                CHEAPEST_GCP="n1-standard-2,0.10,us-central1-a"
            else
                echo -e "${GREEN}Cheapest GCP option: n1-standard-4 (4 vCPU, 15GB RAM, ~\$0.20/hour)${NC}"
                CHEAPEST_GCP="n1-standard-4,0.20,us-central1-a"
            fi
        elif (( $(echo "$min_vcpus <= 4" | bc -l) )); then
            if (( $(echo "$min_ram_mb <= 16384" | bc -l) )); then
                echo -e "${GREEN}Cheapest GCP option: n1-standard-4 (4 vCPU, 15GB RAM, ~\$0.20/hour)${NC}"
                CHEAPEST_GCP="n1-standard-4,0.20,us-central1-a"
            else
                echo -e "${GREEN}Cheapest GCP option: n1-standard-8 (8 vCPU, 30GB RAM, ~\$0.38/hour)${NC}"
                CHEAPEST_GCP="n1-standard-8,0.38,us-central1-a"
            fi
        elif (( $(echo "$min_vcpus <= 8" | bc -l) )); then
            if (( $(echo "$min_ram_mb <= 32768" | bc -l) )); then
                echo -e "${GREEN}Cheapest GCP option: n1-standard-8 (8 vCPU, 30GB RAM, ~\$0.38/hour)${NC}"
                CHEAPEST_GCP="n1-standard-8,0.38,us-central1-a"
            else
                echo -e "${GREEN}Cheapest GCP option: n1-standard-16 (16 vCPU, 60GB RAM, ~\$0.76/hour)${NC}"
                CHEAPEST_GCP="n1-standard-16,0.76,us-central1-a"
            fi
        else
            echo -e "${GREEN}Cheapest GCP option: n1-standard-16 (16 vCPU, 60GB RAM, ~\$0.76/hour)${NC}"
            CHEAPEST_GCP="n1-standard-16,0.76,us-central1-a"
        fi
        
        return 0
    fi
    
    # For GPU models
    echo -e "${YELLOW}Looking for GPU instances...${NC}"
    
    # Consider both GPU memory requirements and optimal GPU type
    if [ "$optimal_gpu_type" = "T4" ] || [ "$min_gpu_memory" -le 16 ]; then
        if [ "$min_vcpus" -le 4 ] && [ "$min_ram_mb" -le 16384 ]; then
            echo -e "${GREEN}Cheapest GCP option: n1-standard-4 + NVIDIA T4 (4 vCPU, 15GB RAM, NVIDIA T4 GPU, ~\$0.35/hour)${NC}"
            CHEAPEST_GCP="n1-standard-4-t4,0.35,us-central1-b"
        elif [ "$min_vcpus" -le 8 ] && [ "$min_ram_mb" -le 32768 ]; then
            echo -e "${GREEN}Cheapest GCP option: n1-standard-8 + NVIDIA T4 (8 vCPU, 30GB RAM, NVIDIA T4 GPU, ~\$0.53/hour)${NC}"
            CHEAPEST_GCP="n1-standard-8-t4,0.53,us-central1-b"
        else
            echo -e "${GREEN}Cheapest GCP option: n1-standard-16 + NVIDIA T4 (16 vCPU, 60GB RAM, NVIDIA T4 GPU, ~\$0.91/hour)${NC}"
            CHEAPEST_GCP="n1-standard-16-t4,0.91,us-central1-b"
        fi
    elif [ "$optimal_gpu_type" = "L4" ] || [ "$min_gpu_memory" -le 24 ]; then
        if [ "$min_vcpus" -le 4 ] && [ "$min_ram_mb" -le 16384 ]; then
            echo -e "${GREEN}Cheapest GCP option: g2-standard-4 (4 vCPU, 16GB RAM, NVIDIA L4 GPU, ~\$0.71/hour)${NC}"
            CHEAPEST_GCP="g2-standard-4,0.71,us-central1-a"
        elif [ "$min_vcpus" -le 8 ] && [ "$min_ram_mb" -le 32768 ]; then
            echo -e "${GREEN}Cheapest GCP option: g2-standard-8 (8 vCPU, 32GB RAM, NVIDIA L4 GPU, ~\$0.85/hour)${NC}"
            CHEAPEST_GCP="g2-standard-8,0.85,us-central1-a"
        elif [ "$min_vcpus" -le 16 ] && [ "$min_ram_mb" -le 65536 ]; then
            echo -e "${GREEN}Cheapest GCP option: g2-standard-16 (16 vCPU, 64GB RAM, NVIDIA L4 GPU, ~\$1.15/hour)${NC}"
            CHEAPEST_GCP="g2-standard-16,1.15,us-central1-a"
        else
            echo -e "${GREEN}Cheapest GCP option: g2-standard-32 (32 vCPU, 128GB RAM, NVIDIA L4 GPU, ~\$1.73/hour)${NC}"
            CHEAPEST_GCP="g2-standard-32,1.73,us-central1-a"
        fi
    elif [ "$optimal_gpu_type" = "A10G" ] || [ "$min_gpu_memory" -le 24 ]; then
        echo -e "${GREEN}Cheapest GCP option: a2-highgpu-1g (12 vCPU, 85GB RAM, NVIDIA A10G GPU, ~\$1.50/hour)${NC}"
        CHEAPEST_GCP="a2-highgpu-1g,1.50,us-central1-a"
    elif [ "$optimal_gpu_type" = "A100" ] || [ "$min_gpu_memory" -gt 24 ]; then
        if [ "$min_gpu_memory" -le 40 ]; then
            echo -e "${GREEN}Cheapest GCP option: a2-highgpu-1g (12 vCPU, 85GB RAM, NVIDIA A100 GPU, ~\$3.67/hour)${NC}"
            CHEAPEST_GCP="a2-highgpu-1g,3.67,us-central1-a"
        else
            echo -e "${GREEN}Cheapest GCP option: a2-highgpu-2g (24 vCPU, 170GB RAM, 2x NVIDIA A100 GPU, ~\$7.35/hour)${NC}"
            CHEAPEST_GCP="a2-highgpu-2g,7.35,us-central1-a"
        fi
    fi
    
    return 0
}

# Function to find the cheapest Azure instance for a model
find_cheapest_azure() {
    local model="$1"
    local performance="${2:-standard}"  # Default to standard if not specified
    
    local requirements=$(get_model_requirements "$model" "$performance")
    local parsed_req=$(parse_model_requirements "$requirements")
    
    local min_vcpus=$(echo "$parsed_req" | cut -d',' -f1)
    local min_ram_mb=$(echo "$parsed_req" | cut -d',' -f2)
    local min_gpu_memory=$(echo "$parsed_req" | cut -d',' -f3)
    local min_gpu_count=$(echo "$parsed_req" | cut -d',' -f4)
    local optimal_gpu_type=$(echo "$parsed_req" | cut -d',' -f5)
    local perf_level=$(echo "$parsed_req" | cut -d',' -f6)
    
    echo -e "${BLUE}Finding cheapest Azure instance for $model (performance: $perf_level)${NC}"
    echo -e "${YELLOW}Requirements: $min_vcpus vCPUs, $(echo "$min_ram_mb/1024" | bc) GB RAM, $min_gpu_memory GB GPU memory, $min_gpu_count GPU(s)${NC}"
    if [ "$optimal_gpu_type" != "none" ]; then
        echo -e "${YELLOW}Optimal GPU type: $optimal_gpu_type${NC}"
    fi
    
    # Check if Azure data is available
    if [ ! -f "$AZURE_CACHE" ]; then
        echo -e "${RED}Azure instance data not available. Run 'fetch-instances' first.${NC}"
        return 1
    fi
    
    # For CPU-only models (min_gpu_memory = 0)
    if [ "$min_gpu_memory" = "0" ]; then
        echo -e "${YELLOW}Looking for CPU-only instances...${NC}"
        
        # Define cheap CPU-only options with approximate hourly prices (hardcoded for simplicity)
        if (( $(echo "$min_vcpus <= 2" | bc -l) )); then
            if (( $(echo "$min_ram_mb <= 8192" | bc -l) )); then
                echo -e "${GREEN}Cheapest Azure option: Standard_D2s_v5 (2 vCPU, 8GB RAM, ~\$0.096/hour)${NC}"
                CHEAPEST_AZURE="Standard_D2s_v5,0.096,eastus"
            else
                echo -e "${GREEN}Cheapest Azure option: Standard_D4s_v5 (4 vCPU, 16GB RAM, ~\$0.192/hour)${NC}"
                CHEAPEST_AZURE="Standard_D4s_v5,0.192,eastus"
            fi
        elif (( $(echo "$min_vcpus <= 4" | bc -l) )); then
            if (( $(echo "$min_ram_mb <= 16384" | bc -l) )); then
                echo -e "${GREEN}Cheapest Azure option: Standard_D4s_v5 (4 vCPU, 16GB RAM, ~\$0.192/hour)${NC}"
                CHEAPEST_AZURE="Standard_D4s_v5,0.192,eastus"
            else
                echo -e "${GREEN}Cheapest Azure option: Standard_D8s_v5 (8 vCPU, 32GB RAM, ~\$0.384/hour)${NC}"
                CHEAPEST_AZURE="Standard_D8s_v5,0.384,eastus"
            fi
        elif (( $(echo "$min_vcpus <= 8" | bc -l) )); then
            if (( $(echo "$min_ram_mb <= 32768" | bc -l) )); then
                echo -e "${GREEN}Cheapest Azure option: Standard_D8s_v5 (8 vCPU, 32GB RAM, ~\$0.384/hour)${NC}"
                CHEAPEST_AZURE="Standard_D8s_v5,0.384,eastus"
            else
                echo -e "${GREEN}Cheapest Azure option: Standard_D16s_v5 (16 vCPU, 64GB RAM, ~\$0.768/hour)${NC}"
                CHEAPEST_AZURE="Standard_D16s_v5,0.768,eastus"
            fi
        else
            echo -e "${GREEN}Cheapest Azure option: Standard_D16s_v5 (16 vCPU, 64GB RAM, ~\$0.768/hour)${NC}"
            CHEAPEST_AZURE="Standard_D16s_v5,0.768,eastus"
        fi
        
        return 0
    fi
    
    # For GPU models
    echo -e "${YELLOW}Looking for GPU instances...${NC}"
    
    # Consider both GPU memory requirements and optimal GPU type
    if [ "$optimal_gpu_type" = "T4" ] || [ "$min_gpu_memory" -le 16 ]; then
        if [ "$min_vcpus" -le 6 ] && [ "$min_ram_mb" -le 56000 ]; then
            echo -e "${GREEN}Cheapest Azure option: Standard_NC4as_T4_v3 (4 vCPU, 28GB RAM, NVIDIA T4 GPU, ~\$0.73/hour)${NC}"
            CHEAPEST_AZURE="Standard_NC4as_T4_v3,0.73,eastus"
        elif [ "$min_vcpus" -le 12 ] && [ "$min_ram_mb" -le 112000 ]; then
            echo -e "${GREEN}Cheapest Azure option: Standard_NC8as_T4_v3 (8 vCPU, 56GB RAM, NVIDIA T4 GPU, ~\$1.46/hour)${NC}"
            CHEAPEST_AZURE="Standard_NC8as_T4_v3,1.46,eastus"
        else
            echo -e "${GREEN}Cheapest Azure option: Standard_NC16as_T4_v3 (16 vCPU, 110GB RAM, NVIDIA T4 GPU, ~\$2.93/hour)${NC}"
            CHEAPEST_AZURE="Standard_NC16as_T4_v3,2.93,eastus"
        fi
    elif [ "$optimal_gpu_type" = "V100" ] || [ "$min_gpu_memory" -le 32 ]; then
        if [ "$min_vcpus" -le 6 ] && [ "$min_ram_mb" -le 56000 ]; then
            echo -e "${GREEN}Cheapest Azure option: Standard_NC4s_v3 (4 vCPU, 28GB RAM, NVIDIA V100 GPU, ~\$3.06/hour)${NC}"
            CHEAPEST_AZURE="Standard_NC4s_v3,3.06,eastus"
        elif [ "$min_vcpus" -le 12 ] && [ "$min_ram_mb" -le 112000 ]; then
            echo -e "${GREEN}Cheapest Azure option: Standard_NC8s_v3 (8 vCPU, 56GB RAM, NVIDIA V100 GPU, ~\$6.12/hour)${NC}"
            CHEAPEST_AZURE="Standard_NC8s_v3,6.12,eastus"
        else
            echo -e "${GREEN}Cheapest Azure option: Standard_NC16s_v3 (16 vCPU, 112GB RAM, 2x NVIDIA V100 GPU, ~\$12.24/hour)${NC}"
            CHEAPEST_AZURE="Standard_NC16s_v3,12.24,eastus"
        fi
    elif [ "$optimal_gpu_type" = "A100" ] || [ "$min_gpu_memory" -gt 32 ]; then
        echo -e "${GREEN}Cheapest Azure option: Standard_ND40rs_v2 (40 vCPU, 672GB RAM, 8x NVIDIA V100 GPU, ~\$26.07/hour)${NC}"
        CHEAPEST_AZURE="Standard_ND40rs_v2,26.07,eastus"
    fi
    
    return 0
}

# Function to find cheapest option across providers
find_cheapest() {
    local model="$1"
    local performance="$2"
    
    echo -e "${BLUE}Finding cheapest cloud compute option for $model (performance: $performance)...${NC}"
    
    # First, validate the model name
    get_model_requirements "$model" "$performance" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Invalid model name: $model${NC}"
        echo -e "${YELLOW}Available models: cc-r1:1.5b cc-r1:8b cc-r1:14b cc-r1:32b cc-r1:70b phi mistral gemma:2b llama3:8b qwen:4b${NC}"
        echo -e "${YELLOW}Performance levels: basic, standard, optimal${NC}"
        return 1
    fi
    
    # Fetch instances if needed
    fetch_gcp_instances
    fetch_azure_instances
    
    # Find cheapest options per provider
    find_cheapest_gcp "$model" "$performance"
    find_cheapest_azure "$model" "$performance"
    
    # Compare prices between providers
    local gcp_price=$(echo "$CHEAPEST_GCP" | cut -d',' -f2)
    local azure_price=$(echo "$CHEAPEST_AZURE" | cut -d',' -f2)
    
    echo
    echo -e "${CYAN}===========================================${NC}"
    echo -e "${CYAN}== CHEAPEST OPTION FOR MODEL: $model ==${NC}"
    echo -e "${CYAN}== PERFORMANCE LEVEL: $performance ==${NC}"
    echo -e "${CYAN}===========================================${NC}"
    
    if (( $(echo "$gcp_price < $azure_price" | bc -l) )); then
        local instance=$(echo "$CHEAPEST_GCP" | cut -d',' -f1)
        local zone=$(echo "$CHEAPEST_GCP" | cut -d',' -f3)
        echo -e "${GREEN}Provider:    ${NC}Google Cloud Platform (GCP)"
        echo -e "${GREEN}Instance:    ${NC}$instance"
        echo -e "${GREEN}Zone:        ${NC}$zone"
        echo -e "${GREEN}Price:       ${NC}\$$gcp_price USD/hour"
        echo -e "${GREEN}Command:     ${NC}cc run --cloud=gcp --machine=$instance $model \"Your prompt\""
    else
        local instance=$(echo "$CHEAPEST_AZURE" | cut -d',' -f1)
        local location=$(echo "$CHEAPEST_AZURE" | cut -d',' -f3)
        echo -e "${GREEN}Provider:    ${NC}Microsoft Azure"
        echo -e "${GREEN}Instance:    ${NC}$instance"
        echo -e "${GREEN}Location:    ${NC}$location"
        echo -e "${GREEN}Price:       ${NC}\$$azure_price USD/hour"
        echo -e "${GREEN}Command:     ${NC}cc run --cloud=azure --machine=$instance $model \"Your prompt\""
    fi
    
    return 0
}

# Function to provision a cloud instance for the model
provision() {
    local model="$1"
    local performance="${2:-standard}"  # Default to standard if not specified
    
    if [ -z "$model" ]; then
        echo -e "${RED}Error: Model name is required for provisioning.${NC}"
        echo -e "${YELLOW}Usage: $0 provision <model-name> [performance-level]${NC}"
        return 1
    fi
    
    # Find the cheapest option
    find_cheapest "$model" "$performance"
    
    # Determine which provider to use based on price
    local gcp_price=$(echo "$CHEAPEST_GCP" | cut -d',' -f2)
    local azure_price=$(echo "$CHEAPEST_AZURE" | cut -d',' -f2)
    local provider=""
    local instance=""
    local zone_or_location=""
    
    if (( $(echo "$gcp_price < $azure_price" | bc -l) )); then
        provider="gcp"
        instance=$(echo "$CHEAPEST_GCP" | cut -d',' -f1)
        zone_or_location=$(echo "$CHEAPEST_GCP" | cut -d',' -f3)
    else
        provider="azure"
        instance=$(echo "$CHEAPEST_AZURE" | cut -d',' -f1)
        zone_or_location=$(echo "$CHEAPEST_AZURE" | cut -d',' -f3)
    fi
    
    echo
    echo -e "${YELLOW}Note: Provisioning a cloud instance will incur charges on your cloud account.${NC}"
    read -p "Do you want to provision this instance? (y/n): " confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "${YELLOW}Provisioning canceled.${NC}"
        return 0
    fi
    
    echo -e "${BLUE}Provisioning instance for $model (performance: $performance)...${NC}"
    
    # Generate a unique instance name with performance tier
    local instance_name="cc-${model//:/-}-${performance}-$(date +%s)"
    
    # Startup script to install docker and cc-cli
    local startup_script=$(cat <<EOF
#!/bin/bash
# Update package lists
apt-get update

# Install Docker
apt-get install -y docker.io

# Add user to docker group
usermod -aG docker \$USER

# Create a script to install cc-cli
cat > /home/\$USER/install-cc-cli.sh <<EOL
#!/bin/bash
curl -fsSL https://get.anthropic.com/claude-cli | sh
EOL

# Make the script executable
chmod +x /home/\$USER/install-cc-cli.sh

# Create a file with information about the provisioned instance
cat > /home/\$USER/instance-info.txt <<EOL
Model: ${model}
Performance tier: ${performance}
Instance type: ${instance}
Provider: ${provider}
Date provisioned: $(date)
EOL
EOF
)
    
    # Provision based on provider
    case "$provider" in
        "gcp")
            if ! is_authenticated "gcp"; then
                echo -e "${RED}Not authenticated with GCP. Run 'cc login --gcp' first.${NC}"
                return 1
            fi
            
            echo -e "${BLUE}Provisioning GCP instance: $instance in zone $zone_or_location${NC}"
            
            # Check if there's an SSH key, add one if needed
            echo -e "${YELLOW}Checking for SSH keys...${NC}"
            local ssh_key_exists=$(gcloud compute project-info describe --format="json" | jq -r '.commonInstanceMetadata.items[] | select(.key=="ssh-keys") | .value' 2>/dev/null)
            
            if [ -z "$ssh_key_exists" ]; then
                echo -e "${YELLOW}No SSH keys found in project metadata. Adding your SSH key...${NC}"
                # Generate SSH key if needed
                if [ ! -f ~/.ssh/id_rsa.pub ]; then
                    echo -e "${YELLOW}No SSH key found. Generating one...${NC}"
                    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
                fi
                
                # Add SSH key to project metadata
                gcloud compute project-info add-metadata --metadata-from-file=ssh-keys=~/.ssh/id_rsa.pub
            else
                echo -e "${GREEN}SSH keys found in project metadata.${NC}"
            fi
            
            # Create the instance
            echo -e "${BLUE}Creating instance $instance_name...${NC}"
            gcloud compute instances create "$instance_name" \
                --machine-type="$instance" \
                --zone="$zone_or_location" \
                --image-family=ubuntu-2004-lts \
                --image-project=ubuntu-os-cloud \
                --metadata="startup-script=$startup_script" \
                --boot-disk-size=50GB
            
            # Wait for instance to be ready
            echo -e "${YELLOW}Waiting for instance to be ready...${NC}"
            local instance_ready=false
            local retries=0
            while [ "$instance_ready" = false ] && [ $retries -lt 10 ]; do
                echo "Checking if instance is ready... (attempt $((retries+1)))"
                if gcloud compute ssh "$instance_name" --zone="$zone_or_location" --command="echo 'SSH connection successful'" -- -o "StrictHostKeyChecking=no" >/dev/null 2>&1; then
                    instance_ready=true
                else
                    sleep 10
                    retries=$((retries+1))
                fi
            done
            
            if [ "$instance_ready" = true ]; then
                echo -e "${GREEN}Instance $instance_name is ready!${NC}"
                echo -e "${YELLOW}To connect to your instance:${NC}"
                echo -e "${CYAN}gcloud compute ssh $instance_name --zone=$zone_or_location${NC}"
                echo -e "${YELLOW}To run $model:${NC}"
                echo -e "${CYAN}cc run --cloud=gcp --machine=$instance $model \"Your prompt\"${NC}"
                echo -e "${YELLOW}To terminate this instance when done:${NC}"
                echo -e "${CYAN}gcloud compute instances delete $instance_name --zone=$zone_or_location${NC}"
            else
                echo -e "${RED}Timed out waiting for instance to be ready. You can try connecting manually:${NC}"
                echo -e "${CYAN}gcloud compute ssh $instance_name --zone=$zone_or_location${NC}"
            fi
            ;;
            
        "azure")
            echo -e "${RED}Azure provisioning is not yet implemented.${NC}"
            echo -e "${YELLOW}For Azure, please provision manually using the Azure portal or CLI.${NC}"
            ;;
            
        *)
            echo -e "${RED}Error: Unsupported provider: $provider${NC}"
            return 1
            ;;
    esac
    
    return 0
}

# Function to show usage
show_usage() {
    echo -e "${CYAN}CC CLI Cloud Compute Finder${NC}"
    echo "Usage: $0 [command] [options]"
    echo
    echo -e "${CYAN}Commands:${NC}"
    echo "  fetch-instances              Fetch and cache instance data from cloud providers"
    echo "  find-cheapest <model> [perf] Find the cheapest instance across providers for the specified model"
    echo "                              Optional [perf] can be 'basic', 'standard', or 'optimal'"
    echo "  provision <model> [perf]     Provision an instance for the specified model"
    echo "                              Optional [perf] can be 'basic', 'standard', or 'optimal'"
    echo "  help                         Show this help message"
    echo
    echo -e "${CYAN}Examples:${NC}"
    echo "  $0 find-cheapest cc-r1:8b           # Find cheapest instance with standard performance"
    echo "  $0 find-cheapest llama3:8b optimal  # Find cheapest instance with optimal performance"
    echo "  $0 provision mistral basic          # Provision a basic instance for cost-saving"
    echo
    echo -e "${CYAN}Available Models:${NC}"
    echo "  cc-r1:1.5b, cc-r1:8b, cc-r1:14b, cc-r1:32b, cc-r1:70b"
    echo "  phi, mistral, gemma:2b, llama3:8b, qwen:4b"
    echo
    echo -e "${CYAN}Performance Levels:${NC}"
    echo "  basic    - Lowest cost, CPU-only for smaller models, minimum viable specs"
    echo "  standard - Balanced cost/performance (default), suitable GPU for good performance"
    echo "  optimal  - Best performance, higher tier GPUs with more resources"
    echo
}

# Main function
main() {
    if [ $# -eq 0 ]; then
        show_usage
        exit 0
    fi
    
    case "$1" in
        fetch-instances)
            fetch_gcp_instances
            fetch_azure_instances
            ;;
        find-cheapest)
            if [ -z "$2" ]; then
                echo -e "${RED}Error: Model name is required.${NC}"
                echo -e "${YELLOW}Usage: $0 find-cheapest <model-name> [performance-level]${NC}"
                exit 1
            fi
            
            local model="$2"
            local performance="standard"
            
            # Check if a performance level was specified
            if [ ! -z "$3" ]; then
                performance="$3"
                # Validate performance level
                if [[ "$performance" != "basic" && "$performance" != "standard" && "$performance" != "optimal" ]]; then
                    echo -e "${RED}Error: Invalid performance level: $performance${NC}"
                    echo -e "${YELLOW}Valid performance levels: basic, standard, optimal${NC}"
                    exit 1
                fi
            fi
            
            find_cheapest "$model" "$performance"
            ;;
        provision)
            if [ -z "$2" ]; then
                echo -e "${RED}Error: Model name is required.${NC}"
                echo -e "${YELLOW}Usage: $0 provision <model-name> [performance-level]${NC}"
                exit 1
            fi
            
            local model="$2"
            local performance="standard"
            
            # Check if a performance level was specified
            if [ ! -z "$3" ]; then
                performance="$3"
                # Validate performance level
                if [[ "$performance" != "basic" && "$performance" != "standard" && "$performance" != "optimal" ]]; then
                    echo -e "${RED}Error: Invalid performance level: $performance${NC}"
                    echo -e "${YELLOW}Valid performance levels: basic, standard, optimal${NC}"
                    exit 1
                fi
            fi
            
            provision "$model" "$performance"
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            echo -e "${RED}Error: Unknown command: $1${NC}"
            show_usage
            exit 1
            ;;
    esac
}

# Run the main function
main "$@"