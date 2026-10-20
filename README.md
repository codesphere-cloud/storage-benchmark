# Codesphere storage benchmark

This repository compares the filesystem visible at `/home/user/app` in otherwise equivalent Codesphere workspaces. It covers metadata-heavy CRUD across many small files and sequential CRUD of a large file.

## Run in Codesphere

1. Wait for the `Build benchmark image` GitHub Action to publish `ghcr.io/codesphere-cloud/storage-benchmark:main`.
2. Create one workspace for each storage backend using that image as the custom workspace image. Keep the plan, volume size, source revision, and benchmark settings identical.
3. Run the **Prepare** stage in each workspace.
4. Download or compare `benchmark-results/latest.txt`. Detailed output for every operation is under the timestamped directory printed at the end of the run.

The image is required because Codesphere prepare steps execute inside the workspace image, not inside a service image declared in the run stage. It contains `fio`, `smallfile`, Python, `jq`, and filesystem inspection utilities and runs as Codesphere's normal `1501:1010` workspace identity.

The default suite runs:

- 10,000 small 4 KiB files with one thread;
- 40,000 small 4 KiB files with four threads;
- create, read, stat, rename, and delete operations;
- an 8 GiB direct-I/O sequential create, read, overwrite, and delete test.

Small-file creates use `fsync` by default, and large-file writes finish with `fsync`, so the results include durable-storage latency rather than only client caching.

## Configuration

Set environment variables in the workspace before running `./benchmark.sh`, or change the prepare command in a CI profile:

| Variable | Default | Meaning |
| --- | --- | --- |
| `SMALLFILE_THREADS` | `1 4` | Space-separated concurrency levels |
| `SMALLFILE_FILES` | `10000` | Files processed by each thread |
| `SMALLFILE_SIZE_KIB` | `4` | Small-file size in KiB |
| `SMALLFILE_FSYNC` | `Y` | Fsync every created small file (`Y` or `N`) |
| `LARGE_FILE_SIZE` | `8G` | Large-file test size |
| `FIO_DIRECT` | `1` | Bypass the page cache for fio (`1` or `0`) |
| `BENCHMARK_ROOT` | `$PWD/.storage-benchmark-data` | Temporary benchmark data |
| `RESULTS_DIR` | `$PWD/benchmark-results` | Persistent result files |

For a short smoke test:

```bash
SMALLFILE_THREADS=1 \
SMALLFILE_FILES=10 \
LARGE_FILE_SIZE=16M \
./benchmark.sh
```

Run the full suite at least three times per backend and compare medians. Alternate the order between Ceph and cephless runs, and use fresh volumes when measuring first-use behavior. Provisioning time is deliberately outside this benchmark and should be measured separately.

## Local image test

```bash
docker build -t storage-benchmark:test .
docker run --rm \
  -e SMALLFILE_THREADS=1 \
  -e SMALLFILE_FILES=10 \
  -e LARGE_FILE_SIZE=16M \
  -v "$PWD:/home/user/app" \
  storage-benchmark:test \
  ./benchmark.sh
```
