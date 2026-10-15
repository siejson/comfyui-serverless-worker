#!/usr/bin/env bash
# Download the models (billed worker time, ~1 min on a fast host), then hand over to the base image's /start.sh
# (GPU check, ComfyUI, Runpod queue handler).
#
# Slow-host guard: if less than MIN_GB arrived in the first CHECK_S seconds, exit so this worker is dropped instead of
# billing for a crawl (one pod on 2026-10-14 managed 11 MB/s: ~50 min for these 33 GB).
set -uo pipefail
: "${CHECK_S:=60}" "${MIN_GB:=4}"
t0=$(date +%s)
$PY /fetch_models.py /models.json /comfyui krea-kroma > /tmp/models.log 2>&1 &
fetch=$!

for _ in $(seq "$CHECK_S"); do kill -0 $fetch 2>/dev/null || break; sleep 1; done
if kill -0 $fetch 2>/dev/null; then
    got=$(du -sbc /comfyui/models /comfyui/.downloads 2>/dev/null | tail -1 | cut -f1)
    echo "worker: $((got / 1000000)) MB after ${CHECK_S} s"
    if [ "$got" -lt $((MIN_GB * 1000000000)) ]; then
        echo "worker: slow host (under ${MIN_GB} GB in ${CHECK_S} s), exiting"
        kill $fetch; cat /tmp/models.log; exit 1
    fi
fi
if ! wait $fetch; then echo "worker: model download failed"; cat /tmp/models.log; exit 1; fi
cat /tmp/models.log
echo "worker: models ready $(($(date +%s) - t0)) s after start"
exec /start.sh
