#!/usr/bin/env python3
import argparse
import json
import os
import sys
import time
from pathlib import Path


def eprint(message: str) -> None:
    print(message, file=sys.stderr, flush=True)


def download(args: argparse.Namespace) -> int:
    from funasr import AutoModel

    target = Path(args.models_dir) / args.local_name
    target.mkdir(parents=True, exist_ok=True)
    os.environ["MODELSCOPE_CACHE"] = str(target)
    eprint(f"Preparing FunASR model cache at {target}")
    AutoModel(
        model=args.model,
        vad_model=args.vad_model,
        punc_model=args.punc_model,
        device="cpu",
    )
    (target / ".voiceink-ready").write_text("ready", encoding="utf-8")
    return 0


def transcribe(args: argparse.Namespace) -> int:
    from funasr import AutoModel

    start = time.time()
    model_dir = Path(args.model_dir)
    os.environ["MODELSCOPE_CACHE"] = str(model_dir)

    model = AutoModel(
        model="paraformer-zh",
        vad_model="fsmn-vad",
        punc_model="ct-punc",
        device="cpu",
    )
    result = model.generate(input=args.audio, batch_size_s=300)
    text = ""
    if isinstance(result, list):
        text = "".join(item.get("text", "") for item in result if isinstance(item, dict))
    elif isinstance(result, dict):
        text = result.get("text", "")
    else:
        text = str(result)

    print(json.dumps({"text": text.strip(), "duration": time.time() - start}, ensure_ascii=False), flush=True)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="VoiceInk FunASR helper")
    subparsers = parser.add_subparsers(dest="command", required=True)

    download_parser = subparsers.add_parser("download")
    download_parser.add_argument("--model", required=True)
    download_parser.add_argument("--vad-model", required=True)
    download_parser.add_argument("--punc-model", required=True)
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
