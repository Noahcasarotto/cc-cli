# CC CLI

A simple command-line tool for running CC AI models locally.

## What is CC CLI?

CC CLI is a user-friendly command-line interface that makes it easy to install, manage, and run CC AI models on your local machine. It's built on top of Ollama and provides simplified commands for common tasks.

## Features

- **Simple Installation**: One command to install everything
- **Easy Model Management**: Download and switch between different CC models
- **Intuitive Commands**: Simple, memorable commands for running AI models
- **Cross-Platform**: Works on macOS and Linux
- **Configurable**: Set default models and preferences

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

## Technical Details

CC CLI is a bash script wrapper around Ollama, making it easier to use CC models specifically. It handles:

1. Installation of Ollama
2. Model download and management
3. Configuration preferences
4. Simple command-line interface

## License

[MIT License](LICENSE)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Credits

- [CC AI](https://github.com/cc-ai) for their excellent models
- [Ollama](https://ollama.com) for making local LLM inference possible
