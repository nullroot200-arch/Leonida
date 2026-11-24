# LEONIDA 12C.14 - Windows 11 environment

## 1. Access result

The Windows 11 test PC was **not accessible** from this Freebuff session. The
session remained on the existing Debian VM; no remote Windows endpoint was
provided or authorized.

Commands checked on 2026-11-24:

| Probe | Result |
|---|---|
| `command -v pwsh` | MISSING |
| `command -v powershell` | MISSING |
| `command -v cmd.exe` | MISSING |
| `command -v wsl.exe` | MISSING |
| `command -v wine` | MISSING (a private Wine runner exists under `/tmp`, but it is not a Windows host) |
| `ls -ld /mnt/c/Windows` | No such file or directory |

No Windows registry, Windows SDK, Visual Studio, PowerShell or native Windows
kernel was reachable. No result in this package was produced on Windows 11.

## 2. Current Linux host

| Item | Observed value |
|---|---|
| OS | Debian 13.8 |
| Kernel | 6.12.118 |
| Architecture | x86-64 |
| Logical CPUs | 4 |
| RAM | approximately 14 GiB |
| Free space | `/home` approximately 112 GiB; `/tmp` approximately 1.4 GiB |
| Physical GPU | none exposed |
| `/dev/dri` | absent |
| NVIDIA driver / `nvidia-smi` | not present |
| Vulkan loader | 1.4.309 |
| Vulkan device | `llvmpipe (LLVM 19.1.7, 256 bits)`, `PHYSICAL_DEVICE_TYPE_CPU` |
| Vulkan ICDs visible | gfxstream, Intel HASVK, Intel, lavapipe, nouveau, radeon, virtio |
| D3D12 native runtime | not available on Linux |
| Windows D3D12/DXGI DLLs | not available |

`vulkaninfo --summary` exited 0 and reported:

```
Vulkan Instance Version: 1.4.309
deviceType = PHYSICAL_DEVICE_TYPE_CPU
deviceName = llvmpipe (LLVM 19.1.7, 256 bits)
driverName = llvmpipe
driverID   = DRIVER_ID_MESA_LLVMPIPE
```

This is a software Vulkan device. It is not evidence of a Vulkan physical device
or GPU PASS. See `mission12c14-vulkan-gpu-validation.md`.

## 3. Intended Windows 11 test machine

The prior context describes an AMD Ryzen 9, NVIDIA RTX 4070 Ti and 16 GB RAM.
Those values are **not verified** here and must be detected by
`collect_environment.ps1`, not assumed. A different Windows machine must not be
silently substituted.

The Windows collector now checks:

* Windows caption, version, build, architecture and 64-bit state;
* CPU name and logical processor count;
* RAM;
* all `Win32_VideoController` adapters, driver versions and PNP IDs;
* Visual Studio and the MSVC x64 toolset through `vswhere`;
* Windows SDK versions and the 10.0.26100 minimum;
* CMake, CTest, Ninja, Git and Python;
* `vulkaninfo`, `nvidia-smi`, DXC, FXC, glslang, `spirv-as` and `spirv-val`;
* `MSVCP140.dll`, `VCRUNTIME140.dll` and `VCRUNTIME140_1.dll` in
  `%WINDIR%\System32`, including their PE machine, version and SHA-256;
* `d3d12.dll`, `d3d12core.dll`, `dxgi.dll` and `vulkan-1.dll` in System32;
* `VULKAN_SDK`, its headers and its `Bin` directory.

The collector is read-only. It does not install the VC++ Redistributable, a
driver, a Vulkan SDK or a single DLL from a third party.

## 4. Environment labels

| Item | Status |
|---|---|
| Windows 11 native | **NOT VERIFIED** |
| Windows 11 build | **UNKNOWN** |
| MSVC native | **NOT RUN** |
| Windows SDK 10.0.26100 | **NOT VERIFIED** |
| PowerShell | **NOT RUN** (not installed here) |
| VC++ 2015-2022 x64 runtime | **NOT VERIFIED** |
| Physical RTX 4070 Ti | **NOT VERIFIED** |
| D3D12 runtime | **NOT VERIFIED** |
| DXGI runtime | **NOT VERIFIED** |
| Vulkan Windows loader | **NOT VERIFIED** |
| Vulkan physical device | **BLOCKED** |

## 5. Reproducible Windows collection

From the repository root on Windows:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  tools\leonida-verify\windows\collect_environment.ps1 `
  -OutDir C:\leonida-reports\12c14
```

The output is `environment.json`, `environment.txt` and the JSON sidecar. The
collector exits 2 when a core prerequisite, including the x64 VC++ runtime, is
missing. Missing prerequisites must be documented, not worked around with
unverified DLLs.

Return the complete `environment.json` before running any build or probe.
