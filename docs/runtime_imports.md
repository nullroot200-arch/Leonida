# Runtime: measured imports of the shipped modules

`gta6rt --dry-run` maps an x86-64 image, applies base relocations, binds every import through the shim
registry or the host, and prints a report. It does **not** call `DllMain`, TLS callbacks or the entry point, so
this page measures mapping and binding only; it does not claim the modules work.

The game executable is still missing from the package available here. Every other PE that the package ships is
present, and all of them are Xbox Series builds. Running the dry-run over those images is the closest thing to a
loader test that does not need the executable.

## Reproduce

Build the runtime, then point it at the package:

```powershell
powershell -File scripts/build_runtime.ps1

$game = "D:\path\to\your\package"
runtime\build\gta6rt.exe --dry-run "$game\XboxBvhBuilder.dll" --game-dir $game
```

Each run prints one line per mapped module:

```
XboxBvhBuilder.dll  base=0000000180000000 size=909312 entry=+0x227cc  shim=2 host=55 module=0 unimplemented=0
    shim          d3d12_xs.dll!D3D12SerializeVersionedRootSignature
    shim          xmem.dll!XMemVirtualQuery
1 module(s) mapped, 0 unimplemented import(s)
```

`shim` counts imports served by the clean-room tables, `host` counts imports served by the desktop DLLs,
`module` counts imports served by another bundled image, and `unimplemented` counts imports with no binding.

## Measured result

All 16 DLLs in the package map at their preferred base `0x180000000` with no relocation, and every import binds:

| Image | Size of image | Entry RVA | Shim | Host | Module | Unimplemented |
|---|---:|---:|---:|---:|---:|---:|
| `Bink2Scarlett.dll` | 278,528 | `0x2ac1c` | 4 | 56 | 0 | 0 |
| `XboxBvhBuilder.dll` | 909,312 | `0x227cc` | 4 | 53 | 0 | 0 |
| `amd_fidelityfx_upscaler_xbox.dll` | 802,816 | `0x26780` | 6 | 80 | 0 | 0 |
| `amd_fidelityfx_loader_xbox.dll` | 32,768 | `0x18d0` | 5 | 17 | 0 | 0 |
| `libHttpClient.GDK.dll` | 999,424 | `0x11f0` | 26 | 172 | 0 | 0 |
| `XCurl.dll` | 188,416 | `0x17b0` | 24 | 116 | 0 | 0 |
| `concrt140.dll` | 303,104 | `0x29160` | 2 | 101 | 0 | 0 |
| `msvcp140.dll` | 577,536 | `0x525a0` | 13 | 174 | 0 | 0 |
| `msvcp140_1.dll` | 36,864 | `0x15c0` | 2 | 31 | 0 | 0 |
| `msvcp140_2.dll` | 192,512 | `0x1efa0` | 2 | 94 | 0 | 0 |
| `msvcp140_atomic_wait.dll` | 81,920 | `0x3c80` | 4 | 60 | 0 | 0 |
| `msvcp140_codecvt_ids.dll` | 28,672 | `0x1340` | 2 | 22 | 0 | 0 |
| `vccorlib140.dll` | 344,064 | `0x27e50` | 7 | 107 | 0 | 0 |
| `vcomp140.dll` | 86,016 | `0x6580` | 7 | 71 | 0 | 0 |
| `vcruntime140.dll` | 110,592 | `0xf890` | 3 | 38 | 0 | 0 |
| `vcruntime140_1.dll` | 49,152 | `0x3e90` | 1 | 33 | 0 | 0 |

Since the library-loader shims (`runtime/shims/library_loader.cpp`), a module's `LoadLibrary*`, `GetModuleHandle*`, `GetProcAddress` and `FreeLibrary` imports count as shim, through `kernel32`, `kernelbase` or the `api-ms-win-core-libraryloader-*` set it names. That is why every image above has a few more shim and fewer host imports than before; the Xbox-specific imports below are unchanged. `DisableThreadLibraryCalls` is served the same way: a mapped module gets `TRUE` (the real function refuses a module the Windows loader did not map, which failed the `DllMain` of the four `msvcp140_*` satellite DLLs), and any other handle goes to the real function.

The process shim (`runtime/shims/process.cpp`) serves `ExitProcess` and `GetCommandLineA/W` the same way: through `kernel32`, `kernelbase`, and `api-ms-win-core-processthreads-l1-1-0` and `api-ms-win-core-processenvironment-l1-1-0`, the sets the API-set umbrella libraries (`OneCore_apiset.lib`, `mincore.lib`) bind them to. `vcomp140.dll` imports `ExitProcess` from the first of these. The UCRT's `_get_narrow_winmain_command_line` and `_get_wide_winmain_command_line` are served too, so a `WinMain` executable gets the game's command line as `lpCmdLine`. The table above is `gta6rt --dry-run` on each DLL at the commit that added this paragraph.

The six unique Xbox-specific imports (eight consumer/import pairs) are exactly the set recorded in
[`d3d12_vulkan.md` §7](d3d12_vulkan.md#7-prior-art-and-measured-xbox-abi):

| Consumer | Import | Binding |
|---|---|---|
| `Bink2Scarlett.dll` | `xmem.dll!XMemAlloc` | shim |
| `Bink2Scarlett.dll` | `xmem.dll!XMemFree` | shim |
| `XboxBvhBuilder.dll` | `xmem.dll!XMemVirtualQuery` | shim |
| `XboxBvhBuilder.dll` | `d3d12_xs.dll!D3D12SerializeVersionedRootSignature` | shim |
| `amd_fidelityfx_upscaler_xbox.dll` | `xmem.dll!XMemAlloc` | shim |
| `amd_fidelityfx_upscaler_xbox.dll` | `xmem.dll!XMemFree` | shim |
| `amd_fidelityfx_upscaler_xbox.dll` | `xmem.dll!XMemGetWorkingSetStatistics` | shim |
| `amd_fidelityfx_upscaler_xbox.dll` | `d3d12_xs.dll!D3D12CreateRootSignatureDeserializer` | shim |

The video path (`Bink2Scarlett.dll`), the BVH builder and the FidelityFX upscaler therefore all go through the
two shim DLLs that already exist. `libHttpClient.GDK.dll` and `XCurl.dll` import only desktop APIs.

## Console paths and the write overlay

A title's file calls name the console's drives, so `GAME:\data\x.sps` is a file inside the installed game folder.
[ivall/xcl](https://github.com/ivall/xcl) (GPL-2.0-only; facts only, no code) documents for Xbox Series GDK titles that
`GAME:` maps to the game folder and that writes go to a writable overlay instead of the package, which stays read-only.
`gta6rt` therefore shims `CreateFileA/W`, `FindFirstFileA/W`/`FindNextFileA/W`/`FindClose`, `GetFileAttributesA/W`,
`GetFileAttributesExA/W` and `DeleteFileA/W` (`runtime/shims/file_system.cpp`), under `kernel32.dll`, `kernelbase.dll`
and the `api-ms-win-core-file-*` sets a GDK title links against.

- A `GAME:` path (any case, `\` or `/`) maps under `--game-dir`. A path without the prefix is a host path and is
  passed to the host unchanged. `--game-dir` defaults to the image's folder. `gta6rt` makes it and `--overlay`
  absolute at startup, so a bare image name (`gta6rt --run game.exe` from the game folder) and a relative folder
  both keep naming the same place after the title changes its current directory (CTest `run_tiny_game_dir`).
  `G:\` is the same folder as `GAME:`, and `T:\` is a scratch folder, `<overlay>\.gta6rt-temp`, that `GAME:` does
  not see (RT-218; the other console layers map those two drives this way, and only the executable can say which
  spelling GTA VI uses). A path under `--game-dir` or the overlay is always a host path, so a package that sits on
  a host drive `G:` keeps working, and with no folders configured `G:` and `T:` stay host drives.
- An open that can write, and `DeleteFile`, use the overlay: `--overlay DIR`, default `<game-dir>\overlay`. A
  write-open of a package file copies it into the overlay first, so `OPEN_EXISTING` keeps its bytes. The copy is
  written under `<overlay>\.gta6rt-copy` and renamed into place, one copy-up at a time, so a process killed mid-copy
  or two threads opening the same file never leave a truncated copy under its name; a delete of a
  package file leaves an empty marker under `<overlay>\.gta6rt-deleted`, which reads and listings treat as gone. The
  package is never written.
- Reads prefer the overlay copy and then the package. `FindFirstFile` merges the two folders, the overlay winning on a
  name, and hides deleted names, the marker folder and the copy folder.
- A path that climbs above `GAME:` with `..`, or names another drive, fails with `ERROR_INVALID_NAME`, so a title
  cannot reach outside the package and the overlay.

- `CreateDirectory*` makes the folder in the overlay. A name the title can already see, including a folder only the
  package has, fails with `ERROR_ALREADY_EXISTS`; a missing parent with `ERROR_PATH_NOT_FOUND`.
- `RemoveDirectory*` needs the folder empty in the title's view (`ERROR_DIR_NOT_EMPTY` otherwise). An overlay folder is
  removed; a package folder is hidden by a `.gta6rt-dir` marker inside its marker folder, and stays on disk. A marker
  folder on its own (left by a file deleted below it) does not hide anything.
- `MoveFile*` writes the destination in the overlay. A package file is copied there and its old name deleted by a
  marker; an overlay file or an overlay-only folder is renamed. An existing destination needs
  `MOVEFILE_REPLACE_EXISTING` even when only the package has it. Moving a package folder fails with
  `ERROR_ACCESS_DENIED` (as deleting one does), a move between `GAME:` and a host path with `ERROR_NOT_SAME_DEVICE`, and
  `MOVEFILE_DELAY_UNTIL_REBOOT` with `ERROR_INVALID_PARAMETER`.
- `CopyFile`, `CopyFileEx` and `CopyFile2` read the source the way a read does and write a `GAME:` destination in the
  overlay; fail-if-exists counts a name only the package has. Either side can be a host path.
- `SetFileAttributes*` sets the attributes on the overlay copy, copying a package file up (or mirroring a package
  folder) first, so the package keeps its own.

`runtime/test/file_system_test.cpp` (ctest `file_system`) covers this over folders it makes in `%TEMP%`.

## When an unimplemented import is called

The table above has no unimplemented imports, but the game executable will. A call to one used to return 0
silently, which for an `HRESULT` function is `S_OK` with its out parameters never written; the caller then carries on
with stale pointers and fails somewhere unrelated. `LEONIDA_UNIMPLEMENTED` chooses what the thunk does instead
(details in `runtime/README.md`):

- `log` (default): print the name once, return 0. Unchanged.
- `fail`: return `E_NOTIMPL` for imports known to return `HRESULT`, 0 otherwise.
- `stop`: print the import, the caller as `module+RVA` and rcx/rdx/r8/r9, then break (debugger) or exit with code 3.

The `--dry-run` report ends with `unimplemented by return policy: hresult=N other=N`, so the first run against the
executable shows how many of its missing imports `fail` would turn into errors.

The `HRESULT` list is by DLL and name: `D3D12Create*` and `D3D12Serialize*` (`d3d12.dll`, `d3d12_xs.dll`),
`D3D12GetDebugInterface`, `D3D12EnableExperimentalFeatures`, `CreateDXGIFactory*`, `DXGIGetDebugInterface1`,
`DXGIDeclareAdapterRemovalSupport` (`dxgi.dll`), and in `xgameruntime.dll` `XGameRuntimeInitialize`, `XGameEventWrite`
and the families `XAsync*`, `XTaskQueue*`, `XUser*`, `XStore*`, `XGameSave*`, `XPackage*`, `XGameUi*` except the 33
functions their public reference pages show returning `void`, `bool` or `int` (for example `XTaskQueueDispatch`,
`XUserCloseHandle`, `XStoreIsLicenseValid`). The mixed `XSystem*`, `XGameStreaming*`, `XThread*` and `XDisplay*`
families are not listed. The sources are the Microsoft Learn pages for the D3D12/DXGI functions and the GDK reference
(`gaming/gdk/docs/reference/system/<family>/functions/<name>`); `D3D12XboxCreateDevice` is matched by name from the
measurement in `d3d12_vulkan.md`, because its page could not be found.

## Run-time loaded modules

Not every console module is reached through an import table. `libHttpClient.GDK.dll` and `XCurl.dll` both use the
GDK runtime, but `dumpbin /imports` shows **no import of `xgameruntime.dll`** in either. Both carry the wide string
`xgameruntime.dll` and the ASCII names `InitializeApiImpl`, `InitializeApiImplEx`, `InitializeApiImplEx2`,
`QueryApiImpl` and `UninitializeApiImpl`, next to a statically linked `XGameRuntimeInitialize`. So `xgameruntime.lib`'s
thunks `LoadLibraryW` the runtime and `GetProcAddress` those five names at run time. xodus-gaming/xgameruntime-docs
(GPL-3.0) documents the same mechanism for PC GDK titles: `InitializeApiImplEx2` is what
`XGameRuntimeInitialize[WithOptions]` calls, and `QueryApiImpl` hands out the runtime's COM classes, whose methods
mostly correspond one to one to the `xgameruntime.lib` functions. The executable is very likely linked the same way.

Bound to the host, those calls would load the PC's Gaming Services runtime, or fail, and never reach the offline
shims. `runtime/shims/library_loader.cpp` therefore answers `LoadLibrary*` and `GetModuleHandle*` for a module the
shim registry owns (`rt::shims::owns_dll`: `xgameruntime.dll`, `d3d12_xs.dll`, `xmem.dll`, `gameinput.dll`) with a
pseudo-handle, and `GetProcAddress` on it resolves through the registry. A name the registry doesn't serve is `NULL`
with `ERROR_PROC_NOT_FOUND` and is logged once. Every other module goes to the host unchanged.

`runtime/shims/xgameruntime.cpp` serves the five entry points. The initializers succeed offline and log the GDK
version and mode once. `QueryApiImpl` serves `XThreadingImpl` and `XErrorImpl` (below); for any other class it logs
the class and interface id and returns `0x80070032`, the documented error for a class the runtime doesn't provide, so
the first boot with the executable lists the classes to implement next. `xgameruntime_test` drives this path through
the api-set binding `XCurl.dll` uses, and calls the two classes slot by slot.

`XCurl.dll` has a second way in. One of its functions reads `HKLM\Microsoft\GamingServices` value
`ServiceRetryTimeout`, then `LoadLibraryExW(L"gameplatformservices.dll", nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32)` and
`GetProcAddress`es `GetApiVersionImpl` and `QueryApiImpl`. It calls the first through the CFG dispatch with two
pointers to 64-bit locals (the result is not read), compares the pair with the one it saw last and keeps it. On the
host that load would find a PC's Gaming Services runtime, which bypasses the offline classes, or nothing, in which
case XCurl returns `0x87E00196`. The shims own `gameplatformservices.dll` too: its `QueryApiImpl` is the offline
one, and `GetApiVersionImpl(uint64_t*, uint64_t*)` writes the same two values every time.

### Class layouts, measured

Each `xgameruntime.lib` function the package's DLLs link is a thunk of the same shape: it calls a helper with the
class id (passed as both the class and the interface id), which initializes the runtime once and calls
`QueryApiImpl`; then it calls one vtable slot with `this` followed by the function's own arguments, and calls
`Release` (slot 2). The helper treats `0x80040154` (class not registered) from `QueryApiImpl` specially: it turns it
into `0x89240107` and calls an error hook; any other failure is returned as is.

The slots below were read from the thunks statically linked into `libHttpClient.GDK.dll` and `XCurl.dll`
(disassembled with `llvm-objdump`; no code was run, nothing else read). Every slot called matches, in argument
count and width, the function at that position of xgameruntime-docs' "Layout" list after IUnknown's three slots:

| Class | Slots called | Checked against the documented order |
|---|---|---|
| `XThreadingImpl` (`IXThreadingImpl`, 28 methods, slots 3-30) | 3-7 and 9-30 (`libHttpClient.GDK.dll`), 3, 5, 12, 16-18, 22, 29 (`XCurl.dll`) | e.g. 7 `XAsyncBegin` (5 args), 9 `XAsyncSchedule` (pointer, 32-bit), 10 `XAsyncComplete` (pointer, HRESULT, size), 12 `XTaskQueueCreate` (two 32-bit modes, pointer), 16 `XTaskQueueDispatch` (returns a byte), 19 `XTaskQueueSubmitDelayedCallback` (5 args), 22 `XTaskQueueTerminate` (pointer, bool, two pointers), 27 `XThreadSetTimeSensitive` (bool), 30 `XThreadIsTimeSensitive` (returns a byte). Slot 8 (`XAsyncBeginAlloc`, private) is never called; slot 28 (`XTaskQueueIsEmpty`, private) takes no arguments |
| `XErrorImpl` (`IXErrorImpl`, slots 3-5) | 3 (`XCurl.dll`) | slot 3, the docs' `_unknown_`, takes an HRESULT and a pointer: `XErrorReport(HRESULT, const char*)` |
| `XNetworkingImpl` (`IXNetworkingImpl2`, slots 3-20) | 11-17 (`XCurl.dll`), 3-20 (`libHttpClient.GDK.dll`, each in its documented argument shape, e.g. 18-20 (enum, u64 pointer / u64 / pointer)) | the Utf16 `XNetworkingQuerySecurityInformationForUrl*` trio, `XNetworkingVerifyServerCertificate`, `XNetworkingGetConnectivityHint`, `XNetworkingRegister/UnregisterConnectivityHintChanged` (pointer, bool). Served offline, asked for with `IXNetworkingImpl2`'s id |
| `XSystemImpl` (`IXSystemImpl5`, slots 3-8 known) | 3-8 (`libHttpClient.GDK.dll`) | 3-5 `XSystemGetConsoleId` / `GetXboxLiveSandboxId` / `GetAppSpecificDeviceId` (size, pointer, pointer each), 6 `XSystemHandleTrack` (two pointers, IXSystemImpl3), 7 `XSystemIsHandleValid` (pointer), 8 `XSystemAllowFullDownloadBandwidth` (bool, IXSystemImpl4); IXSystemImpl2 and 5 add no known method. Served offline |
| `XPersistentLocalStorageImpl` (`IXPersistentLocalStorageImpl3`, slots 3-8) | none called (the table of ids only) | slots 3-7 are `XPersistentLocalStorageGetPathSize` / `GetPath` / `GetSpaceInfo` / `PromptUserForSpaceAsync` / `PromptUserForSpaceResult`, slot 8 `XPersistentLocalStorageMountForPackage` (IXPersistentLocalStorageImpl3). Slots from the public xgameruntime-docs and Wine IDL, not measured in a caller. Served offline: the folder is `<overlay>\persistent`, the quota is the 2048 MB of `MicrosoftGame.Config`, a prompt for space the quota holds succeeds, and `MountForPackage` is `E_NOTIMPL` |
| `XPackageImpl` (`IXPackageImpl3`) | 3-19, 22, 24-27, 30, 32-34, 37-40 (`libHttpClient.GDK.dll`) | slots 3-34 are IXPackageImpl's 32 entries, 35-38 IXPackageImpl2's 4, 39-40 IXPackageImpl3's 2. Not served yet |

`XThreadingImpl` forwards each slot to `third_party/xtaskqueue`, the same implementation the named exports use;
`XThreadSetTimeSensitive`/`XThreadIsTimeSensitive` keep a per-thread flag and the two private slots log once and
answer 0. `XErrorImpl` logs each report and hands it to the callback `XErrorSetCallback` set.
`XNetworkingImpl` answers as a console without a network would: the connectivity hint is initialized with no
connectivity (level None), the port and URL security-information queries fail with
`HRESULT_FROM_WIN32(ERROR_NETWORK_UNREACHABLE)` (the `*Async` ones complete with it through XAsync), the
certificate check fails the same way, change registrations return tokens that never fire, and the three
`IXNetworkingImpl2` additions are `E_NOTIMPL`.

Which classes the package's GDK modules reference, from a byte search for the class and interface GUIDs that
xgameruntime-docs lists (16-byte in-memory form, every `.dll` of the package; counts only, nothing else read):

| Module | Runtime classes referenced (highest interface id present) |
|---|---|
| `XCurl.dll` | `XThreadingImpl`, `XErrorImpl`, `XNetworkingImpl` (`IXNetworkingImpl2`) |
| `libHttpClient.GDK.dll` | 24 of the 24 documented classes, each GUID once. Five are called through thunks ("Class layouts, measured" below): `XThreadingImpl` (27 thunks), `XPackageImpl` (30), `XNetworkingImpl` (18), `XSystemImpl` (6), `XErrorImpl` (3); the others are referenced only by the id table. Highest interfaces: `IXSystemImpl5`, `IXUserImpl5` (not 6), `IXGameImpl3`, `IXStoreImpl6`, `IXPackageImpl3` (not 4), `IXGameUiImpl4`, `IXGameSaveImpl3`, `IXGameStreamingImpl3`, `IXPersistentLocalStorageImpl3`, `IXUserDeviceImpl2`, `IXNetworkingImpl2` |
| every other `.dll` | none |

So `XCurl.dll` needs threading, error reporting and networking from the runtime, and the interface versions in
`libHttpClient.GDK.dll` date the GDK the package was built with: newer than the first `IXUserImpl5`, older than
`IXUserImpl6`. The executable's own set is still unmeasured. `QueryApiImpl`'s log gives it on the first boot.

A title that calls `LoadLibrary*`, `GetModuleHandle*`, `GetProcAddress` or `FreeLibrary` on one of the package's
bundled DLLs (`Bink2Scarlett.dll`, `XboxBvhBuilder.dll`, the FidelityFX DLLs) is routed through `rt::Loader` instead of
the host Windows loader (excluding data-file loads and host-preferred CRTs). The loader maps the DLL from `--game-dir`,
binds its console imports (`xmem.dll`, `d3d12_xs.dll`) through the shim registry, runs its `DllMain` and TLS callbacks,
and resolves direct, ordinal and forwarded exports from the mapped image. `run_tiny_bundled_load` exercises this path
end to end with a synthetic bundled DLL importing `xmem.dll!XMemAlloc` and `XMemFree`.

## WinHTTP offline

`XCurl.dll` and `libHttpClient.GDK.dll` do their HTTP through WinHTTP: between them they import 16 functions from
`winhttp.dll` (`WinHttpOpen`, `Connect`, `OpenRequest`, `SendRequest`, `ReceiveResponse`, `QueryHeaders`,
`QueryDataAvailable`, `ReadData`, `WriteData`, `AddRequestHeaders`, `SetOption`, `QueryOption`, `SetTimeouts`,
`SetStatusCallback`, `CloseHandle`, `CrackUrl`) and nothing from Winsock. Nothing here goes online, so `gta6rt` owns
`winhttp.dll` (`runtime/shims/winhttp_offline.cpp`) and answers all 16 in-process:

- Sessions, connections and requests are local handles: no name is resolved and no socket is opened.
- `WinHttpSendRequest` fails with `ERROR_WINHTTP_CANNOT_CONNECT`. On a `WINHTTP_FLAG_ASYNC` session it returns `TRUE`
  and the failure arrives as WinHTTP delivers one: `WINHTTP_CALLBACK_STATUS_REQUEST_ERROR` with `{API_SEND_REQUEST,
  ERROR_WINHTTP_CANNOT_CONNECT}`, on a thread-pool thread, with the request's context. A request closed first gets
  no error callback.
- Reading a response and `WinHttpWriteData` fail with `ERROR_WINHTTP_INCORRECT_HANDLE_STATE`. Options, timeouts and
  headers are accepted; `WINHTTP_OPTION_CONTEXT_VALUE` and `WINHTTP_OPTION_HANDLE_TYPE` can be queried.
- A status callback is inherited by child handles, which report `HANDLE_CREATED`; every handle reports
  `HANDLE_CLOSING` once, last. `WinHttpCrackUrl` only parses; the host parser is preferred, with a local
  http/https/ftp fallback for hosts (such as Wine) whose parser rejects the URL. The fallback supplies default
  ports (80/443/21), accepts credentials, bracketed IPv6 and query/fragment components, and rejects a null URL or
  component table, a wrong `dwStructSize`, an empty authority/port, and an unbracketed host with a second colon
  (`host:80:90`). The current `winhttp_offline` test reports **74 checks**; the earlier 12C.10 report's 65 was a
  stale/undercounted figure, corrected here after rerunning the test in 12C.11. The 12C.10 environment passed 300
  consecutive runs of the then-current binary.
- Because the shims own the module, a title's `LoadLibrary("winhttp.dll")` gets a pseudo-handle too, and a WinHTTP
  function outside these 16 resolves to `NULL` (logged), never to the host.

Each refused server is logged once (`[rt] winhttp: offline, refused <host>:<port>`), which records what a title
tried to reach. `runtime/test/winhttp_offline_test.cpp` (ctest `winhttp_offline`) covers the synchronous and
asynchronous paths with `.invalid` names; it opens no connection.

## What this proves and what it does not

- It proves the loader parses real Xbox Series PE files, maps their sections, applies no unnecessary relocation,
  walks their import tables, and classifies every thunk.
- The loader also registers each image's unwind table. `pe_loader_test` checks, for every DLL present in
  `LEONIDA_GAME_DIR`, that the whole exception directory is registered, that `RtlLookupFunctionEntry` returns
  each entry for its first byte, and that the entry point is covered (directly, or through the `jmp rel32` thunks
  an incrementally linked entry point goes through: a thunk touches no stack, so it has no entry of its own).
  Measured on all 16 DLLs: every table passes the loader's checks and every entry resolves to itself.

  | Image | Unwind entries | Entry point |
  |---|---:|---|
  | `Bink2Scarlett.dll` | 527 | covered |
  | `XboxBvhBuilder.dll` | 449 | covered |
  | `amd_fidelityfx_upscaler_xbox.dll` | 477 | covered |
  | `amd_fidelityfx_loader_xbox.dll` | 46 | covered |
  | `libHttpClient.GDK.dll` | 2,452 | `jmp rel32` thunk to a covered function |
  | `XCurl.dll` | 446 | covered |
  | `concrt140.dll` | 1,121 | covered |
  | `msvcp140.dll` | 1,228 | covered |
  | `msvcp140_1.dll` | 45 | covered |
  | `msvcp140_2.dll` | 469 | covered |
  | `msvcp140_atomic_wait.dll` | 86 | covered |
  | `msvcp140_codecvt_ids.dll` | 32 | covered |
  | `vccorlib140.dll` | 697 | covered |
  | `vcomp140.dll` | 195 | covered |
  | `vcruntime140.dll` | 236 | covered |
  | `vcruntime140_1.dll` | 79 | covered |
- It does **not** prove any imported function behaves correctly when called. That needs the executable, or a
  harness that calls a known entry point.
- The executable's own imports are unknown. `MicrosoftGame.Config` names `game_scarlett_master.exe`; the package
  here does not contain it, so its import table cannot be measured yet.
- The CRT images are present in the package, but `pe_loader.cpp` prefers the host copies for the `vcruntime`/
  `msvcp`/`concrt`/`vccorlib`/`vcomp` families. The table above maps the packaged images only to test the
  parser; a real run binds the host copies.
- No game data is stored in this repository. The counts are output of a local run against the user's package.
