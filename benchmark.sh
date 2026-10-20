#!/usr/bin/env bash
set -euo pipefail

benchmark_root="${BENCHMARK_ROOT:-$PWD/.storage-benchmark-data}"
results_root="${RESULTS_DIR:-$PWD/benchmark-results}"
smallfile="${SMALLFILE:-/opt/smallfile/smallfile_cli.py}"
smallfile_threads="${SMALLFILE_THREADS:-1 4}"
smallfile_files="${SMALLFILE_FILES:-10000}"
smallfile_size_kib="${SMALLFILE_SIZE_KIB:-4}"
smallfile_fsync="${SMALLFILE_FSYNC:-Y}"
large_file_size="${LARGE_FILE_SIZE:-8G}"
fio_direct="${FIO_DIRECT:-1}"

run_id="$(date -u +%Y%m%dT%H%M%SZ)"
run_data="$benchmark_root/$run_id"
run_results="$results_root/$run_id"
summary="$run_results/summary.txt"
large_file="$run_data/large/data.bin"

mkdir -p "$run_data/large" "$run_results"
touch "$summary"
rm -f -- "$results_root/latest.txt"
ln "$summary" "$results_root/latest.txt"

read -r -a thread_levels <<< "$smallfile_threads"

exec > >(tee -a "$summary") 2>&1

echo "storage benchmark"
echo "run_id=$run_id"
echo "started_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "working_directory=$PWD"
echo "benchmark_root=$benchmark_root"
echo "smallfile_threads=$smallfile_threads"
echo "smallfile_files_per_thread=$smallfile_files"
echo "smallfile_size_kib=$smallfile_size_kib"
echo "smallfile_fsync=$smallfile_fsync"
echo "large_file_size=$large_file_size"
echo "fio_direct=$fio_direct"
echo "fio_version=$(fio --version)"
echo "smallfile_version=$(cat /opt/smallfile-version 2>/dev/null || echo unknown)"
echo "kernel=$(uname -srmo)"
echo
df -hT "$PWD"
findmnt -T "$PWD" || true

cleanup_data() {
    rm -f -- "$large_file"
    for threads in "${thread_levels[@]}"; do
        python3 "$smallfile" \
            --operation cleanup \
            --top "$run_data/smallfiles-t$threads" \
            --threads "$threads" \
            --files "$smallfile_files" \
            --file-size "$smallfile_size_kib" \
            --record-size "$smallfile_size_kib" \
            --files-per-dir 1000 \
            >/dev/null 2>&1 || true
    done
}
trap cleanup_data EXIT

run_smallfile() {
    local operation="$1"
    local threads="$2"
    local top="$run_data/smallfiles-t$threads"
    local log="$run_results/smallfile-t${threads}-${operation}.txt"
    local common=(
        --top "$top"
        --threads "$threads"
        --files "$smallfile_files"
        --file-size "$smallfile_size_kib"
        --record-size "$smallfile_size_kib"
        --files-per-dir 1000
    )

    mkdir -p "$top"

    echo
    echo "=== smallfile threads=$threads operation=$operation ==="
    if [[ "$operation" == create ]]; then
        python3 "$smallfile" --operation "$operation" "${common[@]}" --fsync "$smallfile_fsync" | tee "$log"
    elif [[ "$operation" == read ]]; then
        python3 "$smallfile" --operation "$operation" "${common[@]}" --verify-read Y | tee "$log"
    else
        python3 "$smallfile" --operation "$operation" "${common[@]}" | tee "$log"
    fi
}

for threads in "${thread_levels[@]}"; do
    run_smallfile cleanup "$threads"
    run_smallfile create "$threads"
    run_smallfile read "$threads"
    run_smallfile stat "$threads"
    run_smallfile rename "$threads"
    run_smallfile delete-renamed "$threads"
    run_smallfile cleanup "$threads"
done

run_fio() {
    local name="$1"
    local rw="$2"
    local log="$run_results/fio-${name}.txt"

    echo
    echo "=== fio operation=$name ==="
    fio \
        --name="$name" \
        --filename="$large_file" \
        --rw="$rw" \
        --bs=1M \
        --size="$large_file_size" \
        --ioengine=psync \
        --iodepth=1 \
        --direct="$fio_direct" \
        --fallocate=none \
        --end_fsync=1 \
        --group_reporting \
        --eta=never \
        | tee "$log"
}

run_fio create-large write
run_fio read-large read
run_fio update-large write

echo
echo "=== large-file delete ==="
/usr/bin/time -f 'elapsed_seconds=%e' -o "$run_results/delete-large.txt" rm -- "$large_file"
cat "$run_results/delete-large.txt"

echo
echo "completed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "results=$run_results"

trap - EXIT
