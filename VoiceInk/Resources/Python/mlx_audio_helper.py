#!/usr/bin/env python3
import argparse
import json
import sys
import time
from pathlib import Path


def eprint(message: str) -> None:
    print(message, file=sys.stderr, flush=True)


def download(args: argparse.Namespace) -> int:
    from modelscope import snapshot_download

    target = Path(args.models_dir) / args.local_name
    target.mkdir(parents=True, exist_ok=True)
    eprint(f"Downloading {args.repo} to {target}")
    snapshot_download(args.repo, local_dir=str(target))
    return 0


def transcribe(args: argparse.Namespace) -> int:
    start = time.time()
    model_dir = str(Path(args.model_dir))

    from mlx_audio.stt.generate import generate_transcription
    from mlx_audio.stt.utils import load_model

    bundle = load_model(model_dir)
    result = generate_transcription(bundle, args.audio, language=None)
    text = getattr(result, "text", "")
    if not text:
        if isinstance(result, dict):
            text = result.get("text") or result.get("transcription") or ""
        else:
            text = str(result)

    print(json.dumps({"text": text.strip(), "duration": time.time() - start}, ensure_ascii=False), flush=True)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="VoiceInk MLX Audio helper")
    subparsers = parser.add_subparsers(dest="command", required=True)

    download_parser = subparsers.add_parser("download")
    download_parser.add_argument("--repo", required=True)
    download_parser.add_argument("--models-dir", required=True)
    download_parser.add_argument("--local-name", required=True)
    download_parser.set_defaults(func=download)

    transcribe_parser = subparsers.add_parser("transcribe")
    transcribe_parser.add_argument("--model-dir", required=True)
    transcribe_parser.add_argument("--audio", required=True)
    transcribe_parser.set_defaults(func=transcribe)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
