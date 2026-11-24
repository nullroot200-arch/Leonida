# LEONIDA 12C.14 - Retry register

No failed test was retried identically. Each retry below followed a diagnosed
cause and a concrete change or a different execution condition.

| # | Failure / observation | Cause | Minimal correction | Verification | Final status |
|---:|---|---|---|---|---|
| 1 | First `d3d12_probe` build: `no member named 'IsolatedMMU' in 'D3D12_FEATURE_DATA_ARCHITECTURE'` | SDK 10.0.26100 puts `IsolatedMMU` in `D3D12_FEATURE_DATA_ARCHITECTURE1`, not the base structure | Removed the unused field from the base-structure print | Rebuild exit 0 | **FIXED** |
| 2 | Probe UTF-8 helper allocated `size - 1` bytes and asked the API to write `size` bytes | Off-by-one in the temporary buffer | Allocate `size`, convert, then resize to `size - 1` | Successful compile and later link; no runtime Windows test | **FIXED (STATIC)** |
| 3 | WARP adapter description used a reinterpret cast from `DXGI_ADAPTER_DESC` to `DXGI_ADAPTER_DESC1` | The base `GetDesc` does not fill `Flags` | Query `IDXGIAdapter1` and call `GetDesc1` | Rebuild exit 0 | **FIXED** |
| 4 | D3D12 hardware selection could pick the first non-software adapter, possibly an Intel iGPU | No preference policy | Prefer NVIDIA vendor `0x10DE`, otherwise first hardware adapter | Rebuild exit 0; selection path not executed on Windows | **FIXED (STATIC)** |
| 5 | `run_validation.ps1` invoked `run_gpu_tests.py` without `--build` | The harness could look in a default build directory instead of the validated one | Added `--build $resolvedBuild` | Static inspection; PowerShell NOT RUN | **FIXED (STATIC)** |
| 6 | CTest exclusion was based on test names only | A selected test could carry `--run`/`--init` in its command line despite its name | Added `ctest -N -V` capture and a per-selected-test command-line scan | Linux cross-host audit: 41 selected, 15 excluded, 0 unsafe | **VERIFIED HERE** |
| 7 | `verify_package.ps1` always wrote `mission = "12C.13"` | Hard-coded mission string | Use `$doc.mission` from the manifest | Static inspection; PowerShell NOT RUN | **FIXED (STATIC)** |
| 8 | Probe WARP smoke under Wine: `WARP_UNAVAILABLE hr=0x80004001` | Wine does not expose a WARP adapter; no physical GPU in the VM | Did not retry as if it were Windows; recorded only as a Wine smoke result | Exit 1, log retained | **BLOCKED (non-native)** |
| 9 | Vulkan headers absent in cross build (`Vulkan_INCLUDE_DIR-NOTFOUND`) | No Vulkan SDK/headers installed in the cross sysroot | Did not install globally or fetch headers; recorded omitted targets | CMake cache inspected; no presentation/Vulkan binaries built | **NOT RUN** |
| 10 | Windows 11, MSVC, PowerShell and RTX 4070 Ti inaccessible | Session is a Debian VM with no Windows host or GPU | Produced a native handoff and a cross-compiled probe; no native result invented | `pwsh`/`powershell`/`cmd.exe`/`wsl.exe`/`/mnt/c/Windows` all absent | **BLOCKED** |

## 1. Evidence tied to retries

The successful probe build after retry 1:

```text
cmake --build /tmp/leonida-toolchain/build-12c10 --parallel 4 --target d3d12_probe
[2/2] Linking CXX executable d3d12_probe.exe
BUILD_EXIT=0
```

The selected-command audit:

```text
LIST_EXIT=0
selected 41 excluded 15 unsafe 0
```

## 2. What was not retried

* No Windows test was retried because no Windows execution was possible.
* No GPU test was retried on llvmpipe as a substitute for hardware.
* No test threshold was relaxed.
* No failing test was disabled or deleted.
* No Vulkan SDK, driver, runtime or DLL was installed globally.
* No game executable or `--init`/`--run` invocation was attempted.

## 3. Residual failures

The D3D12 hardware, Windows WARP, Vulkan hardware, GPU shader, swapchain and
presentation gates remain unexecuted. They are limitations, not resolved
failures.
