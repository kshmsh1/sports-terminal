#!/usr/bin/env python3
"""Bundle the generated NBA static corpus into deterministic gzip shards.

The browser can address any original JSON path without publishing tens of
thousands of loose files. Paths are assigned to shards with FNV-1a so Dart can
calculate the shard number without a separate lookup manifest.
"""

from __future__ import annotations

import argparse
import gzip
import json
import shutil
from pathlib import Path

DEFAULT_BUCKETS = 512


def fnv1a_32(value: str) -> int:
    result = 0x811C9DC5
    for byte in value.encode("utf-8"):
        result ^= byte
        result = (result * 0x01000193) & 0xFFFFFFFF
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--buckets", type=int, default=DEFAULT_BUCKETS)
    args = parser.parse_args()

    if args.buckets < 1:
        parser.error("--buckets must be positive")
    if not args.input.is_dir():
        parser.error(f"input directory does not exist: {args.input}")

    paths = sorted(
        path.relative_to(args.input).as_posix()
        for path in args.input.rglob("*.json")
        if path.is_file()
    )
    if not paths:
        parser.error("input corpus contains no JSON files")

    assignments: list[list[str]] = [[] for _ in range(args.buckets)]
    for relative in paths:
        assignments[fnv1a_32(relative) % args.buckets].append(relative)

    if args.output.exists():
        shutil.rmtree(args.output)
    args.output.mkdir(parents=True)

    total_uncompressed = 0
    total_compressed = 0
    for bucket, members in enumerate(assignments):
        target = args.output / f"bundle_{bucket:03d}.json.gz"
        with gzip.open(target, "wt", encoding="utf-8", compresslevel=9) as out:
            out.write("{")
            first = True
            for relative in members:
                source = args.input / relative
                raw = source.read_text(encoding="utf-8").strip()
                # Fail here rather than shipping a corrupt public bundle.
                json.loads(raw)
                if not first:
                    out.write(",")
                first = False
                out.write(json.dumps(relative, ensure_ascii=False))
                out.write(":")
                out.write(raw)
                total_uncompressed += source.stat().st_size
            out.write("}")
        total_compressed += target.stat().st_size

    manifest = {
        "contract": "sports-terminal-static-nba-bundles-v1",
        "algorithm": "fnv1a32",
        "bucket_count": args.buckets,
        "file_count": len(paths),
        "uncompressed_bytes": total_uncompressed,
        "compressed_bytes": total_compressed,
    }
    (args.output / "bundle_manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )
    ratio = total_compressed / total_uncompressed if total_uncompressed else 0
    print(json.dumps({**manifest, "compression_ratio": round(ratio, 4)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
