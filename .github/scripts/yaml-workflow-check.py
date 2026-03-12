#!/usr/bin/env python3
"""
yaml-workflow-check.py — validate .github/workflows/*.yml files for:
  1. YAML syntax errors
  2. Duplicate keys (at any nesting level)

Exits 0 if clean, 1 if any issues found.
Usage: python3 .github/scripts/yaml-workflow-check.py [paths...]
  paths: glob patterns or file paths (default: .github/workflows/*.yml)
"""

import sys
import glob
import yaml
from typing import Any


class DuplicateKeyError(ValueError):
    pass


class _DupCheckLoader(yaml.SafeLoader):
    pass


def _construct_mapping(loader: yaml.SafeLoader, node: yaml.MappingNode, deep: bool = False) -> dict:
    loader.flatten_mapping(node)
    pairs = loader.construct_pairs(node, deep=True)
    seen: dict = {}
    duplicates: list = []
    for key, _ in pairs:
        if key in seen:
            if key not in duplicates:
                duplicates.append(key)
        seen[key] = True
    if duplicates:
        raise DuplicateKeyError(f"Duplicate keys: {duplicates} (line ~{node.start_mark.line + 1})")
    return dict(pairs)


_DupCheckLoader.add_constructor(
    yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG,
    _construct_mapping,
)


def check_file(path: str) -> list[str]:
    """Return list of error strings for a file, empty if clean."""
    errors = []
    try:
        with open(path) as f:
            content = f.read()
        yaml.load(content, Loader=_DupCheckLoader)
    except DuplicateKeyError as e:
        errors.append(f"Duplicate key error: {e}")
    except yaml.YAMLError as e:
        errors.append(f"YAML syntax error: {e}")
    except OSError as e:
        errors.append(f"Cannot read file: {e}")
    return errors


def main() -> int:
    # Build file list from args or default pattern
    if len(sys.argv) > 1:
        paths: list[str] = []
        for arg in sys.argv[1:]:
            expanded = glob.glob(arg)
            if expanded:
                paths.extend(sorted(expanded))
            else:
                paths.append(arg)
    else:
        paths = sorted(glob.glob(".github/workflows/*.yml"))

    if not paths:
        print("yaml-workflow-check: no files to check")
        return 0

    total_errors = 0
    for path in paths:
        errors = check_file(path)
        if errors:
            for err in errors:
                print(f"VIOLATION: {path}")
                print(f"  {err}")
                print()
            total_errors += len(errors)

    if total_errors == 0:
        print(f"✅ yaml-workflow-check: {len(paths)} file(s) clean")
        return 0
    else:
        print(f"❌ yaml-workflow-check: {total_errors} error(s) found in {len(paths)} file(s)")
        return 1


if __name__ == "__main__":
    sys.exit(main())
