#!/bin/bash

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# CC CLI path
CC_CLI="$HOME/bin/cc"

# Test prompt
PROMPT="What is the capital of France? Answer in one word."

# Function to test a model
test_model() {
    local model=$1
    echo -e "${YELLOW}Testing $model...${NC}"
    
    # Start time
    start_time=$(date +%s.%N)
    
    # Run the model and capture output
    output=$("$CC_CLI" run "$model" "$PROMPT" 2>&1)
    
    # End time
    end_time=$(date +%s.%N)
    
    # Calculate duration
    duration=$(echo "$end_time - $start_time" | bc)
    
    echo -e "${GREEN}Model: $model${NC}"
    echo -e "Response time: ${duration}s"
    echo -e "Response: $output"
    echo "----------------------------------------"
}

# Test each model
echo "Starting model response time tests..."
echo "Test prompt: $PROMPT"
echo "----------------------------------------"

# Test phi (default)
test_model "phi"

# Test deepseek models
test_model "deepseek-r1:1.5b"
test_model "deepseek-r1:8b"

# Test mistral if installed
if "$CC_CLI" list | grep -q "mistral"; then
    test_model "mistral"
fi

# Test gemma:2b if installed
if "$CC_CLI" list | grep -q "gemma:2b"; then
    test_model "gemma:2b"
fi

echo "All tests completed!" 