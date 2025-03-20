
# DeepSeek CLI

A simple command-line tool for running DeepSeek AI models locally.

## What is DeepSeek CLI?

DeepSeek CLI is a user-friendly command-line interface that makes it easy to install, manage, and run DeepSeek AI models on your local machine. It's built on top of Ollama and provides simplified commands for common tasks.

## Features

- **Simple Installation**: One command to install everything
- **Easy Model Management**: Download and switch between different DeepSeek models
- **Intuitive Commands**: Simple, memorable commands for running AI models
- **Cross-Platform**: Works on macOS and Linux
- **Configurable**: Set default models and preferences

## Quick Installation

```bash
# Clone this repository
git clone https://github.com/Noahcasarotto/deepseek-cli.git
cd deepseek-cli

# Run the installer
bash install.sh
```

Or install with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/Noahcasarotto/deepseek-cli/main/install.sh | bash
```

## Usage

### Install Ollama and Download DeepSeek Model

```bash
deepseek install
```

### Run DeepSeek

```bash
# Run with interactive prompt
deepseek run

# Run with a specific prompt
deepseek run "What is quantum computing?"

# Run a specific model
deepseek run deepseek-r1:14b "Explain the theory of relativity"
```

### Manage Models

```bash
# List available models
deepseek list

# Download a specific model
deepseek pull deepseek-r1:8b

# Set default model
deepseek set-default deepseek-r1:14b
```

### Configuration

```bash
# Enable verbose mode
deepseek verbose on

# Disable verbose mode
deepseek verbose off
```

## Available DeepSeek Models

| Model | Size | Description | Recommended RAM |
|-------|------|-------------|----------------|
| deepseek-r1:1.5b | ~1.1GB | Lightweight model for basic tasks | 8GB+ |
| deepseek-r1:8b | ~4.9GB | Good balance of capability and resource usage | 16GB+ |
| deepseek-r1:14b | ~8.5GB | Better performance but requires more resources | 32GB+ |
| deepseek-r1:32b | ~19GB | Advanced capabilities but requires significant resources | 32-64GB+ |
| deepseek-r1:70b | ~40GB | Most capable but requires powerful hardware | 64GB+ |

## Performance Tips

- Smaller models (1.5B, 8B) run faster but have more limited capabilities
- Larger models (14B, 32B, 70B) offer better reasoning but require more RAM and processing power
- First-time model loading is slower as the model gets optimized for your hardware
- Subsequent runs are faster as the model remains cached

## Technical Details

DeepSeek CLI is a bash script wrapper around Ollama, making it easier to use DeepSeek models specifically. It handles:

1. Installation of Ollama
2. Model download and management
3. Configuration preferences
4. Simple command-line interface

## License

[MIT License](LICENSE)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Credits

- [DeepSeek AI](https://github.com/deepseek-ai) for their excellent models
- [Ollama](https://ollama.com) for making local LLM inference possible
