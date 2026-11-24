# LEONIDA 12C.14 - Performance

## 1. Scope

Only the synthetic CPU import/export path was measurable. No D3D12, Vulkan GPU,
shader, swapchain or presentation timing exists. No GTA 6 FPS is reported or
predicted.

## 2. Benchmark execution

| Item | Value |
|---|---|
| Binary | `/tmp/leonida-toolchain/build-12c10/import_export_bench.exe` |
| Runner | private Wine 12C.8 runner, cross-host |
| Work directory | `/tmp/leonida-toolchain/bench-12c14` |
| Log | `/tmp/leonida-toolchain/logs-12c14-bench.log` |
| Start/end | 2026-11-24T17:31:55Z (one-second resolution) |
| Exit code | 0 |
| Data | synthetic PE images, no code executed, no game content |
| Build | clang-cl, RelWithDebInfo |

The command was:

```text
wine-ns /tmp/leonida-toolchain/build-12c10/import_export_bench.exe /tmp/leonida-toolchain/bench-12c14
```

The benchmark reports median, p95, min and max. It does not emit p99, so p99 is
`NOT MEASURED`. The run duration was below the one-second resolution of the
captured timestamps; no precise harness duration is claimed.

## 3. Import binding results

Nanoseconds per import, median and p95:

| Import count | Median ns/import | p95 ns/import | Min | Max |
|---:|---:|---:|---:|---:|
| 8 | 36,562.50 | 41,925.00 | 35,650.00 | 41,925.00 |
| 64 | 4,393.75 | 5,373.44 | 2,842.19 | 5,373.44 |
| 365 | **1,549.86** | 1,643.01 | 1,530.41 | 1,643.01 |
| 2,000 | **1,459.40** | 1,475.70 | 1,425.75 | 1,475.70 |

The 8-import case has high per-import setup cost because the sample is small and
the initial load work is not amortized. It is not a regression signal.

The 12C.13 report recorded approximately 1,952.88 ns/import for 365 and
1,538.20 ns/import for 2,000 in its own Wine run. The 12C.14 values are similar
(365 lower, 2,000 slightly lower). The runs were not a controlled A/B with
identical process state, so this report does not claim a speedup from the
difference.

## 4. Lookup results

| Operation | Scale | Median ns | p95 ns |
|---|---:|---:|---:|
| module_lookup | 8 | 60.20 | 64.00 |
| module_lookup | 29 | 59.80 | 60.60 |
| module_lookup | 64 | 69.90 | 84.60 |
| export_lookup | 8 | 50.00 | 52.90 |
| export_lookup | 64 | 75.60 | 85.40 |
| export_lookup | 365 | 101.80 | 107.80 |
| export_lookup | 2,000 | 134.60 | 162.90 |

These are CPU parser/lookup measurements. They do not model GPU work, shader
compilation, pipeline creation, resource upload, synchronization or
presentation.

## 5. Hardware and conditions

The host has 4 logical CPUs and approximately 14 GiB RAM. The benchmark ran
through Wine on Debian, not on Windows 11 and not on the Ryzen 9 / RTX 4070 Ti
target. CPU frequency, background load and Wine scheduling are not controlled.
The numbers are reproducible in kind, not certified as native Windows latency.

## 6. Missing measurements

| Measurement | Status |
|---|---|
| Module load on native Windows | **NOT RUN** |
| Import resolution on native Windows | **NOT RUN** |
| Shader compile time | **NOT RUN** |
| Pipeline creation time | **NOT RUN** |
| Resource creation/upload | **NOT RUN** |
| Fence/synchronization latency | **NOT RUN** |
| Present latency / frame time | **NOT RUN** |
| GPU utilization | **NOT MEASURED** |
| Game FPS | **NOT MEASURED** |

No claim above 60 FPS is made. No synthetic result is extrapolated to GTA 6.
