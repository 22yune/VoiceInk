# Python Local ASR Design

## Goal

Add two local Python-backed ASR providers without changing the user's global Python environment:

- `ModelProvider.mlxAudio` for `mlx-audio` models, initially Qwen3-ASR 0.6B and 1.7B 8-bit from ModelScope.
- `ModelProvider.funASR` for CPU-friendly FunASR `paraformer-zh`.

## Architecture

VoiceInk owns isolated Python virtual environments under Application Support. Swift manages model cards, runtime state, downloads, and process execution. Small Python helper scripts perform provider-specific downloads and transcriptions, returning machine-readable JSON on stdout.

MLX Audio and FunASR use separate virtual environments to avoid dependency conflicts. They share a Swift `PythonRuntimeInstaller` for venv creation, pip package installation, and process execution.

## Storage

- MLX Audio runtime: `~/Library/Application Support/com.prakashjoshipax.VoiceInk/MLXAudio/python-env`
- MLX Audio models: `~/Library/Application Support/com.prakashjoshipax.VoiceInk/MLXAudio/models`
- FunASR runtime: `~/Library/Application Support/com.prakashjoshipax.VoiceInk/FunASR/python-env`
- FunASR models: `~/Library/Application Support/com.prakashjoshipax.VoiceInk/FunASR/models`

## Models

MLX Audio:

- `qwen3-asr-0.6b-8bit`, repo `mlx-community/Qwen3-ASR-0.6B-8bit`, Apple Silicon only.
- `qwen3-asr-1.7b-8bit`, repo `mlx-community/Qwen3-ASR-1.7B-8bit`, Apple Silicon only.

FunASR:

- `funasr-paraformer-zh`, CPU, Chinese only, with `fsmn-vad` and `ct-punc`.

## Runtime Behavior

First install/download flow:

1. Validate architecture requirements.
2. Locate `python3` from the user's PATH.
3. Create the provider's private venv.
4. Install provider packages only into that venv.
5. Download the selected model into the provider model directory.
6. Refresh VoiceInk's available models.

If no `python3` is found, VoiceInk reports a retryable runtime error and does not modify the system.

## UI

The Local model list shows Python-backed model cards:

- `Install Runtime` when venv/packages are missing.
- `Download` when runtime is ready but the model is not cached.
- `Set as Default` when the model is cached.
- `Delete Model` and `Show in Finder` for cached models.

MLX Audio cards are disabled on Intel Macs. FunASR cards are available on Intel and Apple Silicon.

## Testing

Unit tests cover provider registration, model metadata, runtime directory layout, and JSON transcript parsing. Build verification covers Xcode project integration.
