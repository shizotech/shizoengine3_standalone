# Network Generators

The `Generators/Network/` directory contains generators for network-based input and output communication.

## Overview

Network generators enable communication with external devices and systems over network protocols.

## Components

| Component | Description |
|-----------|-------------|
| **artnet_receiver.asset** | Artnet protocol receiver |
| **artnet_sender.asset** | Artnet protocol sender |
| **spout_receiver.asset** | Spout2 protocol receiver |

## Protocol Support

### Artnet
- DMX512 over Ethernet protocol
- Supports both sending and receiving
- Commonly used for lighting control integration
- Universe and address configuration available

### Spout
- SPOUT2 video sharing protocol (Windows/macOS)
- Receive video from other applications
- Send video to other applications
- Low-latency inter-app video sharing

## Configuration

Each network generator can be configured with:
- Network interface selection
- Port configuration
- Address/universe settings
- Connection parameters

## Usage

Network generators enable:
- Integration with external lighting consoles
- Video input from other applications
- Video output to external displays/software
- Synchronization with other systems

## Notes

- Network generators run continuously in the background
- Connection status is monitored and reported
- Reconnection logic handles network interruptions
- Some protocols may require specific system libraries

## Navigation

- [Generator Overview](../README.md)
- [Assets Overview](../../README.md)
