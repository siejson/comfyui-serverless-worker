"""Download the manifest's model files for the given workflows (runs on the pod, inside the ComfyUI venv).

usage: fetch_models.py <manifest.json> <comfy_dir> <workflow> [<workflow> ...]

Hugging Face URLs only; hf_xet does the transfer. Files already present with the right size are skipped.
"""

import json
import os
import re
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from huggingface_hub import hf_hub_download

HF_URL = re.compile(r"https://huggingface\.co/([^/]+/[^/]+)/resolve/([^/]+)/(.+)")


def fetch(comfy: Path, path: str, entry: dict) -> str:
    target = comfy / path
    if target.exists() and target.stat().st_size == entry["size"]:
        return f"skip  {path}"
    m = HF_URL.fullmatch(entry["url"])
    if not m:
        raise ValueError(f"not a Hugging Face URL: {entry['url']}")
    repo, revision, filename = m.groups()
    start = time.monotonic()
    staging = comfy / ".downloads"
    got = Path(hf_hub_download(repo, filename, revision=revision, local_dir=staging, token=os.environ.get("HF_TOKEN")))
    if got.stat().st_size != entry["size"]:
        raise ValueError(f"{path}: size {got.stat().st_size}, expected {entry['size']}")
    target.parent.mkdir(parents=True, exist_ok=True)
    os.replace(got, target)
    secs = time.monotonic() - start
    return f"done  {path}  {entry['size'] / 1e9:.2f} GB in {secs:.0f} s ({entry['size'] / 1e6 / max(secs, 1):.0f} MB/s)"


def main() -> None:
    manifest_path, comfy, workflows = sys.argv[1], Path(sys.argv[2]), sys.argv[3:]
    manifest = json.load(open(manifest_path))
    paths = sorted({p for w in workflows for p in manifest["workflows"][w]})
    total = sum(manifest["files"][p]["size"] for p in paths)
    print(f"{len(paths)} files, {total / 1e9:.1f} GB", flush=True)
    start = time.monotonic()
    with ThreadPoolExecutor(max_workers=3) as pool:
        for line in pool.map(lambda p: fetch(comfy, p, manifest["files"][p]), paths):
            print(line, flush=True)
    print(f"all models ready in {time.monotonic() - start:.0f} s", flush=True)


if __name__ == "__main__":
    main()
