# LEONIDA 12C.14 - Native build status

## 1. Result

**MSVC native build: NOT RUN / BLOCKED.**
**Cross-compiled 12C.14 diagnostic target: PASS.**

No MSVC `cl.exe`, Visual Studio Build Tools or Windows SDK is available in this
session. The existing build directory uses a cross toolchain; its output must not
be called a native MSVC build.

## 2. Cross toolchain

| Item | Value |
|---|---|
| CMake build directory | `/tmp/leonida-toolchain/build-12c10` |
| Generator | Ninja |
| Compiler | clang-cl 19.1.7 |
| Linker | lld-link 19.1.7 |
| Target | `x86_64-pc-windows-msvc` |
| Configuration | `RelWithDebInfo` |
| Windows SDK headers/libraries | 10.0.26100 under the local xwin sysroot |
| Date of final 12C.14 target build | 2026-11-24T17:33:18Z (log mtime) |

The 12C.13 `gta6rt.exe` was not rebuilt for this mission. It is included in the
12C.14 package unchanged so that its hashes remain comparable with the previous
report.

## 3. New D3D12 target

`runtime/CMakeLists.txt` now creates `d3d12_probe` when both `D3D12_LIBRARY` and
`DXGI_LIBRARY` are found. It links only the probe to `d3d12`, `dxgi` and `ole32`;
it has no dependency on `gta6rt`, the game loader or any game content.

Build command actually executed:

```text
cmake --build /tmp/leonida-toolchain/build-12c10 --parallel 4 --target d3d12_probe
```

Result:

| Item | Value |
|---|---|
| Exit code | 0 |
| Output | `[2/2] Linking CXX executable d3d12_probe.exe` |
| Binary | `/tmp/leonida-toolchain/build-12c10/d3d12_probe.exe` |
| Size | 34,816 bytes |
| SHA-256 | `d75421344dfb9456ec6004a5ba71279507e1d0a0fcc3fcc87b7f53a3cc4d7b3f` |
| PE format | COFF-x86-64 |
| Subsystem | Windows CUI |
| Imports | `d3d12.dll`, `dxgi.dll`, `ole32.dll`, `KERNEL32.dll`, `MSVCP140.dll`, `VCRUNTIME140.dll`, UCRT API-set DLLs |

The probe uses `D3D12CreateDevice` and `D3D12GetDebugInterface`; it does not
load a game image. A successful link is not a D3D12 execution result.

## 4. Build correction found and fixed

The first compilation failed:

```text
error: no member named 'IsolatedMMU' in 'D3D12_FEATURE_DATA_ARCHITECTURE'
```

The Windows SDK 10.0.26100 structure contains `NodeIndex`, `TileBasedRenderer`,
`UMA` and `CacheCoherentUMA`; `IsolatedMMU` belongs to
`D3D12_FEATURE_DATA_ARCHITECTURE1`. The probe does not need that field. It was
removed; the next build completed with exit 0.

Two probe-only codepaths were also corrected before the successful build:

* UTF-8 conversion now allocates the terminator byte and then resizes the string,
  avoiding a one-byte overwrite;
* the WARP adapter description is obtained as `IDXGIAdapter1::GetDesc1` instead
  of reinterpreting a base `DXGI_ADAPTER_DESC`.

## 5. Configuration warning relevant to this mission

The cross build configured with no Vulkan headers:

```text
Vulkan_INCLUDE_DIR:PATH=Vulkan_INCLUDE_DIR-NOTFOUND
Vulkan_LIBRARY:FILEPATH=Vulkan_LIBRARY-NOTFOUND
Vulkan_GLSLC_EXECUTABLE:FILEPATH=Vulkan_GLSLC_EXECUTABLE-NOTFOUND
Vulkan_GLSLANG_VALIDATOR_EXECUTABLE:FILEPATH=Vulkan_GLSLANG_VALIDATOR_EXECUTABLE-NOTFOUND
```

CMake therefore left out the Vulkan-backed D3D12 device, the Vulkan COM tests,
the GPU test tools, `vk_pipeline_check`, `d3d12_state_map_test`,
`gfx10_descriptors_test` and the presentation tests that require those sources.
The 33 PASS result is a CPU/shim suite, not a GPU suite.

## 6. Native MSVC build required on Windows

From an **x64 Native Tools Command Prompt for Visual Studio 2022**:

```bat
cmake -S runtime -B C:\leonida-build-12c14 -G Ninja ^
  -DCMAKE_BUILD_TYPE=RelWithDebInfo ^
  -DLEONIDA_SDL3=OFF ^
  -DLEONIDA_D3D12_SHIM_TESTS=OFF ^
  -DLEONIDA_VULKAN_HEADERS_FETCH=OFF
cmake --build C:\leonida-build-12c14 --parallel %NUMBER_OF_PROCESSORS%
```

If the Visual Studio generator is preferred, configure a new directory rather
than reusing the 12C.13 directory. Verify `cl.exe` is MSVC, not clang-cl:

```bat
cl 2>&1 | findstr /I "Microsoft"
```

Expected result: `BUILD_NATIVE_MSVC_PASS` only if MSVC and the Windows SDK
10.0.26100 or newer actually configure, compile, link and run the allowed tests.
That label is **NOT AWARDED** in 12C.14.

## 7. Binary ABI notes

`gta6rt.exe` remains a COFF-x86-64 Windows CUI image with `SizeOfImage=892928`,
entry point `0xA21E4`, NX, DYNAMIC_BASE and HIGH_ENTROPY_VA. It imports
`KERNEL32.dll`, `ole32.dll`, `MSVCP140.dll`, `VCRUNTIME140.dll`,
`VCRUNTIME140_1.dll` and the UCRT API sets. The VC++ 2015-2022 x64 runtime is
required but not bundled.

The cross-compiled ABI is not proof that the binary loads on Windows 11. Native
load, imports, TLS host placement and VC++ runtime resolution remain **NOT RUN**
until the handoff is executed.
