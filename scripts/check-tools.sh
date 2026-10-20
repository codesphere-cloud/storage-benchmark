#!/usr/bin/env bash
set -euo pipefail

required=(fio jq python3 findmnt)
for tool in "${required[@]}"; do
    command -v "$tool" >/dev/null || {
        echo "required tool is missing: $tool" >&2
        exit 1
    }
done

smallfile="${SMALLFILE:-/opt/smallfile/smallfile_cli.py}"
test -f "$smallfile" || {
    echo "smallfile was not found at $smallfile" >&2
    exit 1
}

echo "fio: $(fio --version)"
echo "python: $(python3 --version)"
echo "smallfile: $(cat /opt/smallfile-version 2>/dev/null || echo unknown)"
