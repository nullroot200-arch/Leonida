# API and Xbox compatibility inventory

Status: measured static inventory, 2026-11-24 (mission 12C.13). This page describes
the exports registered in `runtime/shims/` and the evidence attached to them. It is
not a claim that every registered function has the console's exact behavior.

## 1. What the count means

The shim registry contains **365 `(module, export)` registrations across 29 module
aliases**. The number counts aliases: the same file or process function is often
registered under `kernel32.dll`, `kernelbase.dll` and several
`api-ms-win-core-*` names. It is therefore not 365 distinct APIs and not 365
verified behaviors.

The reproducible count comes from the same parser as
`tests/test_coverage_guard.py`:

```sh
python3 -I - <<'PY'
import sys
sys.path.insert(0, "tests")
from test_coverage_guard import parse_shim_dir
table = parse_shim_dir("runtime/shims")
print(sum(len(v) for v in table.values()), len(table))
PY
```

Current result: `365 29`.

Revalidated in 12C.13: the parser still reports **365 registrations across 29
aliases**; `xmem` has 81 checks and `pe_loader_bounds` now has **63** checks. The
loader rejects an import descriptor whose `FirstThunk` is zero instead of writing
a resolved pointer into the mapped DOS header, and rejects any declared data
directory that has only one of RVA and size. A successful bundled-module load is
cached per `Loader` for the lifetime of its mappings, so an image with hundreds
of imports from one module does not call `filesystem::exists` for every import.

The 16 shipped package DLLs measured in [runtime_imports.md](runtime_imports.md)
have **0 unimplemented imports** in the dry-run table, but this is a mapping and
binding result, not proof that their code runs or that the executable's imports
are covered.

## 2. Registered surface by logical area

| Area | Registered names | Evidence / status |
|---|---:|---|
| File system and console paths (`GAME:`, overlay, directory/file APIs) | 46 per `kernel32`/`kernelbase`, 33 per `api-ms-win-core-file-l1-1-0`, `l1-2-0`, `l2-1-0` | `file_system` CTest PASS; Windows-native path behavior NOT RUN. |
| Library loader (`LoadLibrary*`, `GetModuleHandle*`, `GetProcAddress`, `FreeLibrary`, `DisableThreadLibraryCalls`) | 9 per five loader API-set aliases | `loader`, `dxgi_passthrough` PASS; no arbitrary lazy load; host fallback only when allowlisted. |
| Process command line / exit (`ExitProcess`, `GetCommandLineA/W`, CRT argv helpers) | 1 + 2 + 14 UCRT aliases + 5 msvcrt | `process_cmdline`, `gta6rt_rejects_*` PASS. |
| Title memory (`VirtualAlloc` with console bits stripped) | 1 per nine aliases | `xmem` PASS (81 checks), Linux/Wine only. |
| `xmem.dll` | 7 | `xmem` PASS (81 checks); `XMemAlloc`, `XMemFree`, `XMemVirtualQuery`, `XMemGetWorkingSetStatistics`, `XMemVirtualAlloc`, `XMemGetWriteWatch`, `XMemResetWriteWatch`. |
| `winhttp.dll` offline | 16 | `winhttp_offline` PASS (74 checks); no socket, no DNS, no network. |
| `d3d12_xs.dll` | 4 | `D3D12XboxCreateDevice`, `D3D12SerializeVersionedRootSignature`, `D3D12SerializeRootSignature`, `D3D12CreateRootSignatureDeserializer`; `device_proxy` SKIP (no WARP), real D3D12 NOT RUN. |
| `xgameruntime.dll` / `gameplatformservices.dll` | 42 registrations (including two `gameplatformservices` aliases and `GameInputCreate`) | `xgameruntime` PASS (106 checks); offline initialization, threading, error, networking, system and persistent-storage classes partial; `XPackageImpl` not served. |
| `gameinput.dll` | 1 (`GameInputCreate`) | Current build DISABLED because SDL3 is absent; no controller test executed. |

The full per-DLL registration list is in `runtime/shims/*.cpp`; the durable
parser is `tests/test_coverage_guard.py`.

## 3. Xbox-specific imports measured from the package

The measured package surface contains **six unique Xbox-specific functions in
eight consumer/import pairs**:

| Consumer | Import | Registered binding |
|---|---|---|
| `Bink2Scarlett.dll` | `xmem.dll!XMemAlloc` | shim |
| `Bink2Scarlett.dll` | `xmem.dll!XMemFree` | shim |
| `XboxBvhBuilder.dll` | `xmem.dll!XMemVirtualQuery` | shim |
| `XboxBvhBuilder.dll` | `d3d12_xs.dll!D3D12SerializeVersionedRootSignature` | shim |
| `amd_fidelityfx_upscaler_xbox.dll` | `xmem.dll!XMemAlloc` | shim |
| `amd_fidelityfx_upscaler_xbox.dll` | `xmem.dll!XMemFree` | shim |
| `amd_fidelityfx_upscaler_xbox.dll` | `xmem.dll!XMemGetWorkingSetStatistics` | shim |
| `amd_fidelityfx_upscaler_xbox.dll` | `d3d12_xs.dll!D3D12CreateRootSignatureDeserializer` | shim |

These are **static import-table facts**, not proof that the corresponding calls
work on a GPU or that the game executable's Xbox imports are covered.

## 4. GDK class surface

`xgameruntime_test` measures the offline `QueryApiImpl` objects:

| Class | Status | Evidence |
|---|---|---|
| `XThreadingImpl` | PARTIAL | thread, task-queue and async slots exercised; `XThreadSetTimeSensitive`/`XThreadIsTimeSensitive` per-thread. |
| `XErrorImpl` | PARTIAL | `XErrorReport` reaches the callback; no full error-service emulation. |
| `XNetworkingImpl` (`IXNetworkingImpl2`) | PARTIAL / offline | connectivity is None; security-info and certificate calls fail with `ERROR_NETWORK_UNREACHABLE`; no network is opened. |
| `XSystemImpl` (`IXSystemImpl5`) | PARTIAL | console ID placeholder, sandbox `RETAIL`, app-specific device ID, handle tracking, bandwidth answer. |
| `XPersistentLocalStorageImpl` | PARTIAL | path, quota (2048 MB), space info and prompt behavior; `MountForPackage` is `E_NOTIMPL`. |
| `XPackageImpl` (`IXPackageImpl3`) | NOT SERVED | `QueryApiImpl` refuses it; package licensing, installation and mount semantics are not claimed. |
| `XUser*`, `XStore*`, `XGameSave*`, `XGameUi*`, `XGameStreaming*`, `XDisplay*` | UNKNOWN / NOT IMPLEMENTED | not represented by a complete measured inventory; no success is invented. |

The package's `libHttpClient.GDK.dll` references 24 documented runtime classes,
but the executable's own class set is still unmeasured. A first authorized boot
would be needed to log it; this campaign did not run one.

## 5. `d3d12_xs` surface

The shim exposes four functions, not the full 23-function console surface measured
from SCARAB. In particular, `D3D12CreateDevice` is absent by design;
`D3D12XboxCreateDevice` is the entry point served. The remaining console-only
functions in [d3d12_xs_surface.md](d3d12_xs_surface.md) are unimplemented if a
title imports them.

The Xbox device/queue/fence ABI is only partly measured. `D3D12XboxCreateDevice`
wraps a PC host device or, when built with Vulkan support and selected by
environment, a Vulkan-backed device. It does not prove:

- the real Xbox device slot table beyond the measured overrides;
- `PresentX`, `SuspendX`, `ResumeX` or frame-event slots;
- `XboxBvhBuilder` end-to-end execution;
- a swapchain, a presented frame, or GPU performance.

## 6. Current verification matrix

| Surface | Linux/Wine CPU | Native Windows | Real GPU |
|---|---|---|---|
| Loader / PE parsing | PASS (63 checks after the 12C.13 directory regression) | NOT RUN | n/a |
| DXGI passthrough | PASS (39 checks) | NOT RUN | n/a |
| WinHTTP offline | PASS (74 checks) | NOT RUN | n/a |
| XMem | PASS (81 checks) | NOT RUN | n/a |
| GameRuntime offline | PASS (106 checks) | NOT RUN | n/a |
| D3D12 device proxy | SKIP (WARP absent) | NOT RUN | NOT RUN |
| Vulkan device/present | BLOCKED (no headers/ICD/device) | NOT RUN | NOT RUN |
| Shader corpus | SKIP (`LEONIDA_SHADERS` absent) | NOT RUN | NOT RUN |
| GameInput | DISABLED (SDL3 absent) | NOT RUN | NOT RUN |
| Xbox API full compatibility | PARTIAL / UNKNOWN | NOT RUN | NOT RUN |

## 7. 12C.13 measured loader changes

| Change | Evidence | Result |
|---|---|---|
| Half-declared data directory rejected | 12 synthetic fixtures (RVA-only and size-only for export, import, relocation, TLS, exception and delay-import) fail on the pre-fix loader and pass after the guard | `pe_loader_bounds`: 63/63 PASS |
| Positive bundled-module cache | `import_export_bench` with synthetic DLLs and 8/64/365/2000 imports | 365 imports: ~9.46 us to ~1.95 us per import; 2000: ~8.51 us to ~1.54 us in the same Wine/RelWithDebInfo environment |
| Stable lookup with larger export tables | 8/64/365/2000 exports, 500 batches of 1000 lookups | median 50 / 75.5 / 101.7 / 135.0 ns; this is CPU lookup, not game or GPU performance |
| Windows harness path policy fixed | `run_validation.ps1` now excludes `^(run_|gta6rt_rejects_)` | Static inspection only; PowerShell NOT RUN |

These numbers describe the runtime's CPU path. They are not FPS, frametime,
GPU throughput, or a GTA 6 compatibility result.

## 8. Open API work

1. Obtain the executable only from the user and with authorization; its import
   table is the missing input for a complete Xbox inventory.
2. Add only APIs proven by a real import and a documented signature; never a
   success-returning stub.
3. Measure the Xbox queue/fence/command-list slots before forwarding them.
4. Run the Windows collector and CTest harness on the authorized Windows host;
   only then replace `NOT RUN` with native results.
5. Keep D3D12 and Vulkan results separate; a software renderer is
   `SOFTWARE VULKAN PASS`, never hardware GPU PASS.
