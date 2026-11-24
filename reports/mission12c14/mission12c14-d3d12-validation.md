# LEONIDA 12C.14 - D3D12 validation

## 1. Verdict

| Check | Status | Evidence |
|---|---|---|
| D3D12 runtime on Windows | **NOT VERIFIED** | no Windows host |
| DXGI on Windows | **NOT VERIFIED** | no Windows host |
| D3D12 WARP on Windows | **NOT RUN** | probe prepared but not executed on Windows |
| D3D12 hardware on RTX 4070 Ti | **NOT RUN / BLOCKED** | no physical GPU or Windows host |
| D3D12 debug layer on Windows | **NOT RUN** | no Windows execution |
| D3D12 device, queue, allocator, list, fence | **NOT RUN on Windows** | only code and cross-link verified |
| D3D12 shader pipeline | **NOT RUN** | no GPU pipeline |
| D3D12 swapchain/presentation | **NOT RUN** | no window/swapchain execution |

No `D3D12_WARP_PASS` or `D3D12_HARDWARE_PASS` is claimed in this mission.

## 2. Independent probe

The new source is `runtime/test/d3d12_probe.cpp`. It is a standalone Windows x64
program with no game dependency. It performs, in order:

1. `CoInitializeEx(COINIT_MULTITHREADED)`;
2. optional `D3D12GetDebugInterface` and `EnableDebugLayer` when `--debug` is
   supplied;
3. `CreateDXGIFactory1`;
4. `EnumAdapters1` over all adapters, printing name, vendor, device, subsystem,
   VRAM, shared memory and flags;
5. WARP selection through `IDXGIFactory4::EnumWarpAdapter`;
6. hardware selection excluding `DXGI_ADAPTER_FLAG_SOFTWARE`, preferring an
   NVIDIA adapter (vendor `0x10DE`) when present;
7. `D3D12CreateDevice(..., D3D_FEATURE_LEVEL_12_0, ...)`;
8. feature-level, architecture, D3D12 options, shader-model and root-signature
   queries;
9. direct command queue, command allocator and command list creation;
10. empty-list close and `ExecuteCommandLists`;
11. fence creation, `Signal(1)`, `SetEventOnCompletion(1, event)` and a 5,000 ms
    wait;
12. separate WARP and hardware summaries.

The binary does not create a window, swapchain, shader or draw. It does not load
an EXE, RPF, TTPF or shader. A device/fence pass would prove only the minimal
D3D12 device path, not game rendering.

## 3. Commands

On Windows 11 x64, from the package directory:

```bat
d3d12_probe.exe --warp
d3d12_probe.exe --hardware
d3d12_probe.exe --debug --hardware
```

Exit codes:

* 0: every requested mode passed;
* 1: requested adapter unavailable or a device/queue/fence check failed;
* 2: usage error.

Status labels:

| Label | Meaning |
|---|---|
| `D3D12_WARP_PASS` | WARP device/queue/fence path completed; **software only** |
| `D3D12_HARDWARE_PASS` | hardware adapter with software flag clear completed the minimal path |
| `D3D12_HARDWARE_UNAVAILABLE` | no hardware adapter; record BLOCKED |
| `D3D12_WARP_UNAVAILABLE` | WARP adapter unavailable; record BLOCKED |
| `D3D12_*_FAIL` | concrete HRESULT or timeout; preserve full output |

## 4. What was verified here

The probe was cross-compiled and linked successfully. Its imports are exactly
the expected Windows runtime, DXGI and D3D12 libraries:

```text
KERNEL32.dll, MSVCP140.dll, VCRUNTIME140.dll,
api-ms-win-crt-{heap,locale,math,runtime,stdio,string}-l1-1-0.dll,
d3d12.dll, dxgi.dll, ole32.dll
```

A Wine argument smoke test returned the documented usage exit 2. A Wine WARP
smoke test returned:

```text
DXGI factory_hr=0x00000000
MODE mode=warp status=WARP_UNAVAILABLE hr=0x80004001
SUMMARY warp=WARP_UNAVAILABLE hardware=NOT_REQUESTED overall=PARTIAL_OR_FAIL
```

This proves only that the executable loads under Wine and handles the unavailable
WARP adapter. **It is not a Windows native test and is not counted.**

## 5. Why the probe cannot be used as a compatibility claim

* device creation is not a shader pipeline;
* a fence wait is not a swapchain presentation;
* WARP is not the RTX 4070 Ti;
* a DXGI adapter name alone does not prove driver stability;
* no GTA 6 content was loaded.

The earliest possible GPU claim is `D3D12_HARDWARE_PASS` for the minimal probe,
and it is still not a GTA 6 compatibility claim.

## 6. Required Windows evidence

Return:

* `d3d12-warp.log`;
* `d3d12-hardware.log`;
* `environment.json` showing the actual adapter, driver and PE architecture of
  `d3d12.dll`/`dxgi.dll`;
* exit codes recorded by `run_validation.ps1`.

If hardware is absent or fails, leave the gate `BLOCKED`/`FAIL`; do not replace
it with WARP.
