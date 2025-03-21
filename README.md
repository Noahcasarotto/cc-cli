# CC CLI

A simple command-line tool for running CC AI models locally with performance optimizations.

## Table of Contents

1. [What is CC CLI?](#what-is-cc-cli)
2. [Features](#features)
3. [Quick Installation](#quick-installation)
4. [Usage](#usage)
5. [Performance Optimizations](#performance-optimizations)
6. [Optimization Details](#optimization-details)
7. [Hardware Analysis](#hardware-analysis)
8. [LLM Optimizations](#llm-optimizations)
9. [Performance Mode](#performance-mode)
10. [Testing Model Performance](#testing-model-performance)
11. [Available CC Models](#available-cc-models)
12. [Performance Tips](#performance-tips)
13. [Cloud Integration](#cloud-integration)
    - [Installing Cloud Dependencies](#installing-cloud-dependencies)
    - [Authenticating with Cloud Providers](#authenticating-with-cloud-providers)
    - [Finding Optimal Cloud Instances](#finding-optimal-cloud-instances)
    - [Cloud Provisioning](#cloud-provisioning)
14. [Technical Details](#technical-details)
15. [Troubleshooting](#troubleshooting)
16. [Advanced Configurations](#advanced-configurations)
17. [License](#license)
18. [Contributing](#contributing)
19. [Credits](#credits)

## What is CC CLI?

CC CLI is a user-friendly command-line interface that makes it easy to install, manage, and run CC AI models on your local machine. It's built on top of Ollama and provides simplified commands for common tasks.

## Features

- **Simple Installation**: One command to install everything
- **Easy Model Management**: Download and switch between different CC models
- **Intuitive Commands**: Simple, memorable commands for running AI models
- **Cross-Platform**: Works on macOS and Linux
- **Configurable**: Set default models and preferences
- **Performance Optimizations**: Hardware-specific optimizations for faster inference
- **Cloud Integration**: 
  - Authenticate with GCP, AWS, and Azure
  - Find the most cost-effective cloud instances for running models
  - Provision and manage cloud instances for resource-intensive models
  - Intelligent hardware requirements calculation based on model parameters

## Quick Installation

```bash
# Clone this repository
git clone https://github.com/Noahcasarotto/cc-cli.git
cd cc-cli

# Run the installer
bash install.sh
```

Or install with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/Noahcasarotto/cc-cli/main/install.sh | bash
```

## Usage

### Install Ollama and Download CC Model

```bash
cc install
```

### Run CC

```bash
# Run with interactive prompt
cc run

# Run with a specific prompt
cc run "What is quantum computing?"

# Run a specific model
cc run cc-r1:14b "Explain the theory of relativity"
```

### Manage Models

```bash
# List available models
cc list

# Download a specific model
cc pull cc-r1:8b

# Set default model
cc set-default cc-r1:14b
```

### Configuration

```bash
# Enable verbose mode
cc verbose on

# Disable verbose mode
cc verbose off
```

## Performance Optimizations

CC CLI includes several tools to optimize the performance of AI models on your local hardware:

- `analyze_hardware.sh`: Analyzes your system and recommends suitable models
- `optimize_llm.sh`: Applies comprehensive optimizations for LLM inference
- `test_models.sh`: Tests and compares the performance of different models

These tools work together to provide a seamless and efficient experience when running CC models.

### Quick Start

```bash
# Analyze your hardware
./analyze_hardware.sh

# Apply optimizations
./optimize_llm.sh

# Test model performance
./test_models.sh

# Use optimized CLI
cc-optimized run "Your prompt here"

# Enable high-performance mode
llm-performance-mode
```

## Optimization Details

The `optimize_llm.sh` script applies the following optimizations:

1. **Metal GPU Optimizations**:
   - Disables debug layers for production performance
   - Configures optimal buffer sizes
   - Sets Apple Silicon specific parameters

2. **Memory Management**:
   - Reduces memory fragmentation
   - Optimizes memory allocation
   - Configures memory mapping thresholds

3. **Thread Optimizations**:
   - Sets optimal thread counts for your CPU
   - Balances workloads across cores
   - Configures numerical libraries for parallelism

4. **System-Level Improvements**:
   - Performance-oriented environment variables
   - I/O optimizations
   - Library-specific settings

5. **Automatic Loading**:
   - Creates LaunchAgent for automatic loading at login
   - Adds environment settings to shell profile
   - Provides convenient wrapper scripts

## Hardware Analysis

The `analyze_hardware.sh` script analyzes your system hardware and provides model recommendations based on:

- CPU type and core count
- Available RAM
- Disk space
- GPU capabilities

### Usage

```bash
./analyze_hardware.sh
```

### Output Example

```
Analyzing system hardware...
----------------------------------------
CPU Information:
Model: Apple M3
Cores: 8

Memory Information:
Total Memory: 8.00GB

Disk Information:
Available Space: 13Gi

GPU Information:
GPU: Chipset Model: Apple M3

Model Recommendation:
Recommended: Use medium-sized models (deepseek-r1:8b)

Performance Optimization Suggestions:
- GPU detected: Consider enabling GPU acceleration
----------------------------------------
```

## LLM Optimizations

The `optimize_llm.sh` script applies comprehensive optimizations for AI model inference:

### Features

1. **Metal GPU Optimizations for Apple Silicon**
   - Disables debug features for production performance
   - Configures optimal buffer sizes
   - Sets Apple Silicon specific parameters

2. **Memory Management Optimizations**
   - Reduces memory fragmentation
   - Optimizes memory allocation
   - Configures memory mapping thresholds

3. **Thread Optimizations**
   - Sets optimal thread counts for your CPU
   - Configures numerical libraries for efficient parallelism

4. **System-Level Improvements**
   - Performance-oriented environment variables
   - Library-specific settings

5. **Automatic Loading**
   - Creates LaunchAgent for automatic loading at login
   - Adds environment settings to shell profile

### Installation

```bash
./optimize_llm.sh
```

### What Gets Installed

- **Environment Files**: Created in `~/.llm-optimizations/`
- **Wrapper Scripts**: 
  - `cc-optimized`: Wrapper for running CC with optimizations
  - `llm-performance-mode`: Script for enabling high-performance mode
- **LaunchAgent**: For automatic loading at login
- **Shell Configuration**: Updates to `~/.zshrc`

### Using Optimized CLI

After running the optimization script, you can use:

```bash
# Run with optimized settings
cc-optimized run "Your prompt here"

# Run with a specific model
cc-optimized run phi "Calculate the square root of 144"
```

## Performance Mode

The `llm-performance-mode` script optimizes system resources for LLM operations:

### Features

- Flushes disk cache for better I/O performance
- Provides performance recommendations
- Optimizes system resources

### Usage

```bash
llm-performance-mode
```

This script requires sudo access to flush the disk cache.

## Testing Model Performance

The `test_models.sh` script allows you to test and compare the performance of different models:

### Features

- Tests multiple models with the same prompt
- Measures response time
- Captures model outputs
- Provides performance comparisons

### Usage

```bash
./test_models.sh
```

### Output Example

```
Starting model phi...
Paris.

total duration:       5.46s
load duration:        68.53ms
prompt eval count:    44 token(s)
prompt eval duration: 2.44s
prompt eval rate:     17.99 tokens/s
eval count:           4 token(s)
eval duration:        2.94s
eval rate:            1.36 tokens/s
```

## Available CC Models

| Model | Size | Description | Recommended RAM |
|-------|------|-------------|----------------|
| cc-r1:1.5b | ~1.1GB | Lightweight model for basic tasks | 8GB+ |
| cc-r1:8b | ~4.9GB | Good balance of capability and resource usage | 16GB+ |
| cc-r1:14b | ~8.5GB | Better performance but requires more resources | 32GB+ |
| cc-r1:32b | ~19GB | Advanced capabilities but requires significant resources | 32-64GB+ |
| cc-r1:70b | ~40GB | Most capable but requires powerful hardware | 64GB+ |

## Performance Tips

- Smaller models (1.5B, 8B) run faster but have more limited capabilities
- Larger models (14B, 32B, 70B) offer better reasoning but require more RAM and processing power
- First-time model loading is slower as the model gets optimized for your hardware
- Subsequent runs are faster as the model remains cached
- Use `llm-performance-mode` before running intensive tasks
- For Apple Silicon, Metal optimizations provide significant speed improvements
- Match thread count to your available CPU cores for optimal performance

## Cloud Integration

CC CLI provides built-in functionality to authenticate and work with major cloud providers, allowing you to leverage cloud resources for running larger models or managing cloud infrastructure.

### Installing Cloud Dependencies

Before using the cloud integration features, you need to install the necessary cloud provider CLIs. A helper script is provided to streamline this process:

```bash
./install_cloud_deps.sh
```

This script will guide you through installing:
- Google Cloud SDK (gcloud)
- AWS CLI
- Azure CLI
- jq (required for JSON processing)

You can also install individual CLIs:

```bash
./install_cloud_deps.sh --gcp   # Install only Google Cloud SDK
./install_cloud_deps.sh --aws   # Install only AWS CLI
./install_cloud_deps.sh --azure # Install only Azure CLI
./install_cloud_deps.sh --all   # Install all without prompting
```

### Authenticating with Cloud Providers

The `cc-login.sh` script allows you to authenticate with all supported cloud providers through a simple interface:

```bash
./cc-login.sh          # Interactive login menu
./cc-login.sh --all    # Login to all configured cloud providers
./cc-login.sh --gcp    # Login to GCP only
./cc-login.sh --aws    # Login to AWS only (supports SSO and access keys)
./cc-login.sh --azure  # Login to Azure only
./cc-login.sh --status # Check authentication status
./cc-login.sh --logout # Logout from all providers
```

#### Authentication Features

The cloud authentication system provides several features:

1. **Multiple Authentication Methods**:
   - AWS: Support for both SSO and traditional access keys
   - Azure: Web-based authentication with subscription selection
   - GCP: Interactive project selection and management

2. **Status Tracking**: The system keeps track of which providers you're authenticated with
3. **Configuration Management**: Cloud provider configurations are stored in `~/.cc-cli/config`
4. **Intelligent Detection**: Automatically detects if you're already logged in
5. **Guided Setup**: Walks you through project/subscription selection where applicable

### Finding Optimal Cloud Instances

The `cloud_compute.sh` script helps you find the most cost-effective cloud instances for running your models. It uses an advanced model requirements calculation system that determines optimal hardware configurations based on model parameters, quantization, and intended use case.

```bash
./cloud_compute.sh find-cheapest <model> [performance-level]
```

Where `<model>` is one of the supported models (cc-r1:1.5b, cc-r1:8b, llama3:8b, etc.) and the optional `[performance-level]` can be:

- `basic`: Lowest cost configuration, CPU-only for smaller models
- `standard`: Balanced cost/performance (default)
- `optimal`: Best performance, higher-tier GPUs with more resources

#### Example Usage

```bash
# Find cheapest instance for running cc-r1:8b with standard performance
./cloud_compute.sh find-cheapest cc-r1:8b

# Find the optimal (highest performance) instance for llama3:8b
./cloud_compute.sh find-cheapest llama3:8b optimal

# Find a basic (lowest cost) instance for phi
./cloud_compute.sh find-cheapest phi basic
```

#### Advanced Model Requirements Calculation

The `cloud_compute.sh` script uses a sophisticated approach to determine hardware requirements:

1. **Model Parameter Analysis**: Calculates resource needs based on model size, context length, and architecture
2. **Quantization Awareness**: Adjusts memory requirements based on quantization method (none, int8, int4)
3. **Performance Tier Scaling**: Scales requirements based on desired performance level
4. **GPU Selection**: Intelligently selects appropriate GPU types based on memory needs
5. **Provider-Specific Optimization**: Considers differences between GCP and Azure instance types

#### Supported Models

The system supports a wide range of models with automatically calculated requirements:

- CC models: cc-r1:1.5b, cc-r1:8b, cc-r1:14b, cc-r1:32b, cc-r1:70b
- Third-party models: phi, mistral, gemma:2b, llama3:8b, qwen:4b

### Cloud Provisioning

The `cloud_compute.sh` script also provides functionality to provision cloud instances based on model requirements:

```bash
./cloud_compute.sh provision <model> [performance-level]
```

This command:
1. Finds the most cost-effective instance across providers
2. Provisions the instance with the necessary configuration
3. Sets up the environment with Docker and CC CLI
4. Provides connection instructions

#### Instance Management

After provisioning, you can:

1. Connect to your instance:
   ```bash
   # For GCP (example)
   gcloud compute ssh <instance-name> --zone=<zone>
   ```

2. Run models on the provisioned instance:
   ```bash
   cc run --cloud=gcp --machine=<machine-type> <model> "Your prompt"
   ```

3. Terminate the instance when done:
   ```bash
   # For GCP (example)
   gcloud compute instances delete <instance-name> --zone=<zone>
   ```

#### Workflow Example

1. Install cloud dependencies and authenticate:
   ```bash
   ./install_cloud_deps.sh --gcp
   ./cc-login.sh --gcp
   ```

2. Find the optimal instance for your model:
   ```bash
   ./cloud_compute.sh find-cheapest cc-r1:70b
   ```

3. Provision an instance:
   ```bash
   ./cloud_compute.sh provision cc-r1:70b
   ```

4. Connect and use the model
5. Terminate when done

## Technical Details

### General Implementation

CC CLI is a bash script wrapper around Ollama, making it easier to use CC models specifically. It handles:

1. Installation of Ollama
2. Model download and management
3. Configuration preferences
4. Simple command-line interface
5. Hardware-specific optimizations

### Metal Optimizations

The following Metal environment variables are configured:

```bash
export MTL_CAPTURE_ENABLED=0
export MTL_DEBUG_LAYER=0
export MTL_MAX_BUFFER_LENGTH=1073741824
export MTL_GPU_FAMILY=apple7
export MTL_GPU_VERSION=1
```

### Memory Management

Memory allocation is optimized with:

```bash
export MALLOC_ARENA_MAX=2
export MALLOC_MMAP_THRESHOLD_=131072
export MALLOC_TRIM_THRESHOLD_=131072
export MALLOC_MMAP_MAX_=65536
```

### Thread Configuration

Thread counts are optimized for your CPU:

```bash
export OMP_NUM_THREADS=$CPU_CORES
export MKL_NUM_THREADS=$CPU_CORES
export VECLIB_MAXIMUM_THREADS=$CPU_CORES
export NUMEXPR_NUM_THREADS=$CPU_CORES
export OPENBLAS_NUM_THREADS=$CPU_CORES
```

### Performance Settings

Additional performance settings include:

```bash
export PYTHONUNBUFFERED=1
export TF_CPP_MIN_LOG_LEVEL=2
export TF_ENABLE_ONEDNN_OPTS=1
export HDF5_USE_FILE_LOCKING=FALSE
```

## Troubleshooting

### Common Issues

1. **LaunchAgent Loading Error**
   
   If you see `Load failed: 5: Input/output error` when running `optimize_llm.sh`, you can try:
   
   ```bash
   sudo launchctl bootstrap system ~/Library/LaunchAgents/com.llm.optimizations.plist
   ```

2. **Permission Issues**
   
   If you encounter permission issues with `llm-performance-mode`, ensure the script is executable:
   
   ```bash
   chmod +x $HOME/bin/llm-performance-mode
   ```

3. **Command Not Found**
   
   If `cc-optimized` or `llm-performance-mode` commands are not found, ensure `$HOME/bin` is in your PATH:
   
   ```bash
   echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
   source ~/.zshrc
   ```

## Advanced Configurations

### Customizing Optimizations

You can customize the optimization settings by editing the configuration files in `~/.llm-optimizations/`:

```bash
# Edit Metal configuration
nano ~/.llm-optimizations/metal.conf

# Edit memory configuration
nano ~/.llm-optimizations/memory.conf

# Edit main environment file
nano ~/.llm-optimizations/environment
```

### Model-Specific Optimizations

For optimal performance with specific models:

- **Small Models (1.5B, 2B)**
  - Ideal for quick responses and basic tasks
  - Works well with minimal optimizations

- **Medium Models (8B)**
  - Benefits from thread optimizations
  - Good balance of performance and capability

- **Large Models (14B+)**
  - Requires full set of optimizations
  - Benefits significantly from GPU acceleration
  - Use `llm-performance-mode` for best results

## License

[MIT License](LICENSE)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Credits

- [CC AI](https://github.com/cc-ai) for their excellent models
- [Ollama](https://ollama.com) for making local LLM inference possible
