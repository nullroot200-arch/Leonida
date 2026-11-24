# ABI, memory and threading contract

Status: Linux/Wine CPU verification, 2026-11-24 (mission 12C.13). This document
describes only behaviour exercised by the current tests. It is not a claim of
native Windows or Xbox compatibility.

## 1. Target and ABI checks

The runtime is built as a 64-bit COFF image for `IMAGE_FILE_MACHINE_AMD64`.
`llvm-readobj --file-headers` reports `COFF-x86-64`, `Arch: x86_64`,
`AddressSize: 64bit` for both `gta6rt.exe` and the synthetic PE test.
`runtime_types` passes 53 checks.

The compile-time checks cover the types that cross the shim boundary:

- pointers, `size_t` and `uintptr_t` are 8 bytes;
- `MEMORY_BASIC_INFORMATION` is 48 bytes, 8-byte aligned; its fields are at the
  Windows SDK offsets, so the 64-byte XMem output has a 16-byte unknown tail;
- `PROCESS_MEMORY_COUNTERS` is 72 bytes and `PROCESS_MEMORY_COUNTERS_EX` is 80
  bytes, with `WorkingSetSize` at offset 16;
- the D3D12 structures used by the root-signature shim, descriptor handles,
  resource descriptions, clear values, boxes, barriers and shader bytecode keep
  their Windows SDK sizes and alignments;
- `D3D12_VERSIONED_ROOT_SIGNATURE_DESC` is 48 bytes and its versioned union starts
  at offset 8.

On Windows x64, `__stdcall` and `WINAPI` use the same register-based calling
convention as the default convention; there is no 32-bit stdcall name decoration
to reproduce. The function-pointer typedefs in `runtime/test/xmem_test.cpp`,
`runtime/test/test_runtime_types.cpp` and `runtime/test/xgameruntime_test.cpp`
therefore describe the same ABI as the registered functions. This was verified
for the current clang-cl build only. MSVC native compilation and native Windows
execution are **NOT RUN**.

No check here proves the Xbox console's private structure layouts. The measured
XMem output prefix is an observed contract, not a complete console definition.

## 2. Memory APIs

| API | State | Verified behaviour | Missing proof |
|---|---|---|---|
| `XMemAlloc` | PARTIAL | 64-byte aligned allocation through `_aligned_malloc`; size 0 becomes a one-byte writable block; free through `XMemFree` | Attribute decoding, console allocation types, exact failure/error contract, huge-size and cross-thread lifetime tests |
| `XMemFree` | PARTIAL | Releases blocks from `XMemAlloc`; null is accepted by the CRT aligned free path | Attribute semantics and double-free/ownership diagnosis; no allocator registry is kept |
| `XMemVirtualQuery` | PARTIAL | Fills a zeroed 64-byte output with the 48-byte `MEMORY_BASIC_INFORMATION` prefix; current-process null handle; null output/address return 0 | Meaning of the 16-byte tail and the console's exact return type/error contract |
| `XMemGetWorkingSetStatistics` | PARTIAL | For the measured `0x20000001` kind, writes the host working-set size at `+8`, zero at `+0`, leaves bytes 16..63 untouched; null output returns FALSE | Full 0x80-byte structure, other kinds, and whether host working-set numbers have console meaning |
| `XMemVirtualAlloc` | PARTIAL | Ordinary and measured 64 KiB page-mode allocation; rejects zero size, large-page mode, unknown type bits and nonzero attributes before host allocation; explicit-address arithmetic is overflow checked | 2 MiB guest mode, console protection bits, exact explicit-address alignment contract, and graphics/title memory |
| `XMemGetWriteWatch` / `XMemResetWriteWatch` | IMPLEMENTED (forwarded) | Direct host `GetWriteWatch` / `ResetWriteWatch`; synthetic write-watch test passes | Console-specific page-mode and error differences |
| `kernel32!VirtualAlloc` via `TitleVirtualAlloc` | PARTIAL | Strips `MEM_GRAPHICS` (`0x10000000`) and `MEM_TITLE` (`0x40000000`), then forwards; nine module aliases | Console protection bits and whether graphics memory needs a shared D3D12/Vulkan arena |

The 12C.12 XMem test adds bounded cases for:

- zero-size allocation returns null with `ERROR_INVALID_PARAMETER`;
- an address plus size that wraps the host address space is rejected;
- the measured 64 KiB page mode returns a host-backed region of at least 64 KiB;
- a null output and a null address in `XMemVirtualQuery` return 0 without an
  invalid write, and null-address output is zero-filled.

These tests do **not** establish that the 64 KiB region has console page
semantics. They only check the host-visible region size and lifetime.

No `HeapAlloc`/`HeapFree` shim is registered. Those calls remain host CRT or
kernel32 calls, depending on the import, and were not reimplemented here.

## 3. Threading and synchronization

The runtime does not claim a complete Win32 thread shim. Thread creation, waits,
events and semaphores used by the host side remain Windows facilities. The
Xbox/GDK surface exposed by `xgameruntime.dll` is the measured partial layer:

| Class | State | Evidence |
|---|---|---|
| `XThreadingImpl` / `IXThreadingImpl` | PARTIAL | task queue creation, submit, dispatch, duplicate, terminate and per-thread time-sensitive slots exercised by `xgameruntime` |
| `XErrorImpl` | PARTIAL | `XErrorReport` reaches the registered callback |
| `XNetworkingImpl` | PARTIAL / offline | no connectivity, security and certificate operations fail explicitly; no network is opened |
| `XSystemImpl` | PARTIAL | console ID, sandbox ID, app-specific device ID and handle tracking |
| `XPersistentLocalStorageImpl` | PARTIAL | path, quota, space info, prompt; package mount returns `E_NOTIMPL` |
| `XPackageImpl` | NOT SERVED | `QueryApiImpl` refuses it |
| `XUser*`, `XStore*`, `XGameSave*`, `XGameUi*`, `XGameStreaming*`, `XDisplay*` | UNKNOWN / NOT IMPLEMENTED | no complete measured implementation or positive test |

The `xgameruntime` CPU test passes 106 checks. It uses bounded queues and waits;
it does not prove absence of races. ThreadSanitizer, AddressSanitizer and
UndefinedBehaviorSanitizer were not available for this Windows cross-build and
are **NOT RUN**. A clean test run is not a race-freedom proof.

## 4. PE loader fixes in 12C.12 and 12C.13

`Loader::bind_imports` rejects a normal import descriptor whose `FirstThunk` is
zero:

```text
<image>: an import descriptor has no address table
```

Before that change, `bind_thunks` accepted the zero IAT RVA, read the mapped DOS
header as a thunk array, and could write a resolved pointer into the image
headers.

12C.13 adds a directory-consistency guard in `Loader::map_image`. For each of the
16 optional-header directories, a non-zero RVA must be paired with a non-zero
size, and a zero RVA with a zero size. A half-written export, import, relocation,
TLS, exception or delay-import entry used to be treated as absent (or, for a zero
RVA, could point the parser at the DOS header). The synthetic regression sets the
RVA-only and size-only form for six directories. On the pre-fix loader all 12
cases loaded successfully; after the guard they are rejected with:

```text
<image>: data directory <index> has only one of RVA and size
```

`pe_loader_bounds` now reports **63 checks**. The 12C.12 `FirstThunk == 0` guard
remains present in the same function.

12C.13 also caches a positive bundled-module resolution per `Loader`. Modules live
until `Loader` destruction, so the cached pointer cannot dangle; misses are not
cached, because a later `LoadLibrary` may add the module. Imports from one DLL no
longer repeat `filesystem::exists` for every symbol. On synthetic images the
binding cost fell from about 9.46 to 1.95 us per import at 365 imports, and from
8.51 to 1.54 us at 2000. The measurement is Wine/clang-cl CPU time, not a
Windows-native or GPU result.

The guard does not validate private console structures, section alignment
against every Microsoft linker rule, or all semantic constraints of a directory
payload. Those remain outside the tested contract.

## 5. Remaining gates

- Native Windows, MSVC and Windows SDK: **NOT RUN**.
- The 12C.13 Windows package is cross-compiled and depends on the Microsoft
  VC++ 2015-2022 x64 redistributable for `MSVCP140`, `VCRUNTIME140` and
  `VCRUNTIME140_1`; its exact version on the target is **UNKNOWN**.
- Real GPU, D3D12 device, Vulkan loader/ICD, presentation and shader execution:
  **NOT RUN/BLOCKED**.
- The 12 `run_*` tests: **NOT RUN**; they invoke `gta6rt --run`.
- The three `gta6rt_rejects_*` tests were also excluded in 12C.12 because they
  pass `--run`/`--init` on the command line even though they expect usage
  rejection.
- No game executable, RPF, TTPF, asset or driver was opened or modified.
