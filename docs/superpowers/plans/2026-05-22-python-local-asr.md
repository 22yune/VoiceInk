# Python Local ASR Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add isolated Python-backed MLX Audio and FunASR local transcription providers.

**Architecture:** Add provider/model types, a shared Python runtime executor, provider-specific managers/services, helper scripts, and model-card UI integration. MLX Audio and FunASR use separate venvs and model caches under VoiceInk Application Support.

**Tech Stack:** Swift 5, SwiftUI, Xcode file-system-synchronized groups, Python venv, `mlx-audio`, `modelscope`, `funasr`.

---

### Task 1: Core Contracts

**Files:**
- Modify: `VoiceInk/Models/TranscriptionModel.swift`
- Modify: `VoiceInk/Models/TranscriptionModelRegistry.swift`
- Modify: `VoiceInk/Models/LanguageDictionary.swift`
- Create: `VoiceInkTests/PythonTranscriptionBackendTests.swift`

- [ ] Add failing tests for new providers, model metadata, and private runtime layout.
- [ ] Add `mlxAudio` and `funASR` provider cases.
- [ ] Add `MLXAudioModel` and `FunASRModel`.
- [ ] Register two Qwen3-ASR models and one Paraformer model.
- [ ] Add provider language dictionaries.

### Task 2: Shared Python Runtime

**Files:**
- Create: `VoiceInk/Transcription/Python/PythonRuntime.swift`
- Create: `VoiceInk/Transcription/Python/PythonTranscriptionResult.swift`
- Create: `VoiceInk/Transcription/Python/PythonProcessRunner.swift`

- [ ] Add tests for JSON parsing and runtime paths.
- [ ] Implement runtime config, status, installation, and process execution.
- [ ] Ensure all package installs target the private venv.

### Task 3: Provider Managers and Services

**Files:**
- Create: `VoiceInk/Transcription/MLXAudio/MLXAudioModelManager.swift`
- Create: `VoiceInk/Transcription/MLXAudio/MLXAudioTranscriptionService.swift`
- Create: `VoiceInk/Transcription/FunASR/FunASRModelManager.swift`
- Create: `VoiceInk/Transcription/FunASR/FunASRTranscriptionService.swift`
- Modify: `VoiceInk/Transcription/Engine/TranscriptionServiceRegistry.swift`
- Modify: `VoiceInk/Transcription/Engine/TranscriptionModelManager.swift`

- [ ] Implement runtime install/download/delete/status for both providers.
- [ ] Implement transcription services that call provider helpers and parse JSON.
- [ ] Make downloaded Python-backed models usable.

### Task 4: Helper Scripts

**Files:**
- Create: `VoiceInk/Resources/Python/mlx_audio_helper.py`
- Create: `VoiceInk/Resources/Python/funasr_helper.py`

- [ ] Implement `download` and `transcribe` commands.
- [ ] Print transcript JSON to stdout only on successful transcription.
- [ ] Send progress and diagnostic logs to stderr.

### Task 5: UI Integration

**Files:**
- Create: `VoiceInk/Views/AI Models/PythonLocalModelCardView.swift`
- Modify: `VoiceInk/Views/AI Models/ModelCardView.swift`
- Modify: `VoiceInk/Views/AI Models/ModelManagementView.swift`
- Modify: `VoiceInk/VoiceInk.swift`

- [ ] Add environment objects for both managers.
- [ ] Add Python-backed model cards in Local and Recommended lists.
- [ ] Add install/download/delete/show in Finder actions.

### Task 6: Verification

**Files:**
- Modify as needed from previous tasks.

- [ ] Run unit tests.
- [ ] Run Xcode build.
- [ ] Report any network-dependent runtime install/download steps that were not executed locally.
