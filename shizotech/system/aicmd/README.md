# AI‑Assisted Command Line Tool

This project provides an AI‑assisted command‑line interface that allows you to interact with a large language model directly from your terminal. The tool connects to a local **vLLM v1 endpoint** that serves models using the **OpenAI Harmony format**.

## Overview

Once configured, you can invoke the AI from anywhere on your system by prefixing a command with an exclamation mark (`!`). The command is sent to the configured model, and the response is returned directly in your shell.

## Requirements

Before using this tool, ensure the following components are installed and running:

* **vLLM** (v1 endpoint)

  * A model that supports the **OpenAI Harmony format** is required.
  * Examples:

    * `gpt-oss-20b`
    * `gpt-oss-120b`
* **shizoscript**

## Setup

1. **Start vLLM**

   Run vLLM with a compatible model and expose a v1 OpenAI‑compatible endpoint.

2. **Install shizoscript**

   Follow the installation instructions for shizoscript appropriate to your system.

3. **Verify connectivity**

   Ensure that your vLLM endpoint is reachable and properly configured for OpenAI‑compatible requests.

## Usage

Once the prerequisites are met, you can access the AI command module from anywhere on your system.

### Launch the AI Command Module

```shell
shz aicmd
```

This command starts the built‑in AI command module and connects it to your configured vLLM endpoint.

### Sending Commands to the AI

To send a prompt to the AI, prefix your command with an exclamation mark (`!`).

Example:

```text
>>> !how much disk space is left?
```

or

```text
>>> !how much is the fish?
```

The tool will forward the prompt to the model and display the response directly in the terminal.

## Notes

* Only commands prefixed with `!` are sent to the AI.
* All other input is treated as standard shell interaction.
* Model quality, latency, and capabilities depend on the model you run in vLLM.

## License

Specify the project license here.

## Contributing

Contributions, bug reports, and feature requests are welcome. Please open an issue or submit a pull request following standard GitHub workflows.
