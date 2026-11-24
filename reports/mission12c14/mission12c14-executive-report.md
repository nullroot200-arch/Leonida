# LEONIDA 12C.14 - Executive report

**Date:** 2026-11-24 (UTC)
**Repository:** `/home/francescohkone/leonida`
**Branch / HEAD:** `lab/verify-manifest` / `aa2988cc555bad7ecd508b48a702adbb32fe7c95`
**Final verdict:** **COMPLETED WITH LIMITATIONS**
**Main objective:** **BLOCKED** - no Windows 11 host is reachable from this session.

## 1. Starting point

The previous mission, 12C.13, closed at **65.35/100** (65% rounded) with the
verdict **READY FOR WINDOWS 11 VALIDATION, NOT READY FOR FIRST LAUNCH**. It had
produced a cross-compiled Windows x64 package, but had not executed it on
Windows. D3D12, Vulkan hardware, GPU shaders, presentation and Xbox semantic
compatibility were still unverified.

This mission was required to test those areas natively. On this host that was
not possible: the session is a Debian 13.8 VM with no Windows partition,
PowerShell, MSVC, Windows SDK, physical GPU, `/dev/dri` or Vulkan hardware
device. The only Vulkan device is Mesa `llvmpipe`, a CPU implementation.

## 2. What was actually completed here

| Work | Result | Evidence |
|---|---|---|
| Revalidate the 12C.13 ZIP | PASS | 857,179 bytes, SHA-256 `bac0f34d0c3b855f360e3fbb6337707a8f5b1ba6f8b718bcee864ab024973546`, 7 members, archive test clean |
| Revalidate package hashes | PASS | `gta6rt.exe`, TLS host, PE bounds test and benchmark all match the 12C.13 manifest |
| Check previous Windows harness | PASS with corrections | CTest command audit: 41 selected, 15 excluded, 0 selected commands containing `--run`/`--init` |
| Add a standalone D3D12 probe | PASS (cross-compiled) | `d3d12_probe.exe`, 34,816 bytes, SHA-256 `d75421344dfb9456ec6004a5ba71279507e1d0a0fcc3fcc87b7f53a3cc4d7b3f` |
| Build the probe | PASS | CMake/Ninja, clang-cl 19.1.7, RelWithDebInfo, exit 0 |
| Safe CPU regression suite | PASS | 41 tests: 33 PASS, 7 SKIP, 1 DISABLED, 0 FAIL; exit 0; 170.34 s |
| CPU import/export benchmark | PASS (synthetic) | 365 imports: median 1,549.86 ns/import; 2000: median 1,459.40 ns/import |
| Create the 12C.14 Windows package | PASS | ZIP SHA-256 `d4049d899d6cef0af5a3e140b50b352dd7912d2e22fa4daab4a2af0e789175d4`, 872,467 bytes |
| Native Windows 11 validation | **NOT RUN / BLOCKED** | No `pwsh`, `powershell`, `cmd.exe`, `wsl.exe` or `/mnt/c/Windows` |
| MSVC native build | **NOT RUN / BLOCKED** | Only clang-cl/lld-link cross-compilation is available |
| D3D12 WARP on Windows | **NOT RUN** | Probe prepared; no Windows execution |
| D3D12 hardware | **NOT RUN / BLOCKED** | No physical GPU or Windows host |
| Vulkan hardware | **BLOCKED** | `vulkaninfo` reports `PHYSICAL_DEVICE_TYPE_CPU`, `llvmpipe`; no `/dev/dri` |
| GPU shader pipeline | **NOT RUN** | No Windows GPU pipeline or shader execution |
| Swapchain and presentation | **NOT RUN** | Presentation binaries are not built in this configuration |
| GTA 6 compatibility | **NOT CLAIMED** | No game content was loaded or executed |

## 3. D3D12 probe

`runtime/test/d3d12_probe.cpp` is a standalone Windows x64 diagnostic. It does
not include any game code or data. It enumerates DXGI adapters, distinguishes
hardware from `DXGI_ADAPTER_FLAG_SOFTWARE`, prefers an NVIDIA adapter when one
is present, creates a D3D12 device, queries feature level, architecture,
options, shader model and root-signature support, then creates a direct command
queue, command allocator, command list and fence, submits an empty list and
waits for the fence.

It prints separate outcomes:

* `D3D12_WARP_PASS` for WARP only; this is **software**, never a GPU PASS;
* `D3D12_HARDWARE_PASS` only for an adapter whose software flag is clear;
* `D3D12_HARDWARE_UNAVAILABLE` or a concrete failure/HRESULT otherwise.

The only execution of this binary here was a Wine argument smoke test and a
Wine WARP smoke test. Wine returned `WARP_UNAVAILABLE` (`0x80004001`). That is
not a Windows result and contributes no points.

## 4. What remains blocked

The four main 12C.13 blocks were not converted into native evidence:

1. Windows 11 native execution.
2. MSVC native build.
3. D3D12 hardware and WARP on Windows.
4. Vulkan physical/logical device, GPU shaders, swapchain and presentation.

Xbox/GDK ABI and semantic compatibility also remain only partially evidenced by
cross-host CPU tests. There is no GTA 6 integration test.

## 5. Files changed in this mission

| Path | Change | SHA-256 |
|---|---|---|
| `runtime/test/d3d12_probe.cpp` | New standalone D3D12 diagnostic | `0c5f863ee313c05cbf1e078d966bbdf5cc22142639992081836ce57ad54a0244` |
| `runtime/CMakeLists.txt` | Adds the `d3d12_probe` target when D3D12 and DXGI libraries exist | `f75ad6af7b9f6cc00997b9594c5131d8df1641609dd95b9d08eaa106a5e4b139` |
| `tools/leonida-verify/windows/collect_environment.ps1` | Adds PE architecture checks for VC++ runtime and D3D12/DXGI/Vulkan files, shader tools and VC++ prerequisite | `82f16a93e77ecc8ffe246a0899af5223542ae3a72ac6766928082dde729e8669` |
| `tools/leonida-verify/windows/run_validation.ps1` | Adds `-RunD3D12Probe`, optional package verification, `--build` for GPU tests and selected-command inspection | `7aa852dc0ddd6a84a960cf0203d1392637302ac699cc8cd9ed146560e98cba7d` |
| `tools/leonida-verify/windows/verify_package.ps1` | Uses the manifest mission instead of hard-coded `12C.13` | `926c1ccaf86762de1de73909659098b74bd5fd694b694089f3d84a35b4bfffe7` |
| `reports/mission12c14/` | This mission's reports, package and hashes | See `mission12c14-artifacts.sha256` |

No game file, RPF, TTPF, executable, shader or asset was modified. No commit,
push, merge, reset, clean or branch change was performed. The pre-existing
modified/untracked files from earlier work were left untouched.

## 6. Readiness statement

The **reported technical maturity remains 65.35/100 (65%)**. This mission did
not increase it: no native Windows, D3D12 hardware, Vulkan hardware, GPU shader,
swapchain or presentation gate passed. The new probe and harness are useful
infrastructure, not evidence of GTA 6 compatibility.

The native graphical gate count is **0 of 7**:

1. native Windows execution: NOT RUN;
2. MSVC native build: NOT RUN;
3. D3D12 WARP: NOT RUN;
4. D3D12 hardware: NOT RUN;
5. Vulkan hardware device: BLOCKED;
6. GPU shader pipeline: NOT RUN;
7. swapchain/presentation: NOT RUN.

## 7. Next action

Execute the handoff in `mission12c14-windows-handoff.md` on the intended Windows
11 x64 machine with the RTX 4070 Ti, from a Visual Studio x64 developer prompt,
after verifying the official VC++ 2015-2022 x64 runtime. Return the complete log
set before any claim about rendering or GTA 6 is made. Do not start GTA 6 and do
not use `gta6rt --init` or `gta6rt --run`.
