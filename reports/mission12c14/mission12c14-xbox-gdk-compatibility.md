# LEONIDA 12C.14 - Xbox/GDK compatibility

## 1. Verdict

| Layer | Status |
|---|---|
| Xbox/GDK export registration inventory | PASS as an inventory (365 registrations, 29 aliases) |
| ABI/shim unit tests on cross-host | PASS (specific synthetic tests) |
| Native Windows ABI validation | **NOT RUN** |
| Xbox/GDK semantic compatibility | **UNKNOWN / PARTIAL** |
| GTA 6 integration | **NOT TESTED** |
| Authentication/licence/DRM emulation | **NOT IMPLEMENTED AND NOT ATTEMPTED** |

A registration is not an implemented API. An export that returns a value is not
semantic compatibility. This report keeps the two separate.

## 2. Inventory

The current inventory in `docs/api_compatibility.md` states:

```text
365 (module, export) registrations across 29 module aliases.
```

It is not 365 distinct APIs: the same implementation is registered under several
`api-ms-win-core-*` names. The `xgameruntime` test reports 106 checks, `xmem` 81,
`pe_loader_bounds` 63, `dxgi_passthrough` 39 and `winhttp_offline` 74. Those are
test counts, not counts of fully compatible Xbox services.

Status vocabulary used below:

* **IMPLEMENTED**: a concrete behavior exists and has a test;
* **PARTIAL**: some behavior exists, but the full service is not claimed;
* **STUB**: a placeholder returns a value without full semantics;
* **NOT SERVED**: the class/API is refused by the implementation;
* **NOT IMPLEMENTED**: no implementation is claimed;
* **UNKNOWN**: semantics cannot be demonstrated from available evidence;
* **TESTED**: the specific tested path passed;
* **BLOCKED**: cannot be tested in this environment.

## 3. GDK module status

| Module / area | Status | Current evidence and limit |
|---|---|---|
| `XThreadingImpl` | PARTIAL | thread, task-queue and async slots exercised; time-sensitive calls are per-thread. No full console scheduler. |
| `XErrorImpl` | PARTIAL | `XErrorReport` reaches a callback; no full error-service emulation. |
| `XNetworkingImpl` | PARTIAL / offline | connectivity is None; security-info and certificate calls fail with `ERROR_NETWORK_UNREACHABLE`; no network opened. |
| `XSystemImpl` (`IXSystemImpl5`) | PARTIAL | console ID placeholder, sandbox `RETAIL`, app-specific device ID, handle tracking, bandwidth answer. Values are offline placeholders. |
| `XPersistentLocalStorageImpl` | PARTIAL | path, 2048 MB quota, space info, prompt behavior; `MountForPackage` returns `E_NOTIMPL`. |
| `XPackageImpl` (`IXPackageImpl3`) | **NOT SERVED** | `QueryApiImpl` refuses it. Package licensing, installation and mount semantics are not claimed. |
| `XUser*` | UNKNOWN / NOT IMPLEMENTED | no complete measured inventory; no success invented. |
| `XStore*` | UNKNOWN / NOT IMPLEMENTED | no complete inventory; no commerce/entitlement emulation. |
| `XGameSave*` | UNKNOWN / NOT IMPLEMENTED | no complete inventory; no cloud-save claim. |
| `XGameUi*` | UNKNOWN / NOT IMPLEMENTED | no complete UI service claim. |
| `XGameStreaming*` | UNKNOWN / NOT IMPLEMENTED | no streaming service claim. |
| `XDisplay*` | UNKNOWN / NOT IMPLEMENTED | no display service claim; presentation is separately NOT RUN. |

The previous report's wording is preserved: `XPackageImpl` is not served, and
the UI/store/user/save/streaming/display families are not represented by a
complete measured inventory. They must not be marked IMPLEMENTED because a
symbol exists.

## 4. D3D12 Xbox surface

`d3d12_xs.dll` has four measured registrations:

* `D3D12XboxCreateDevice`;
* `D3D12SerializeVersionedRootSignature`;
* `D3D12SerializeRootSignature`;
* `D3D12CreateRootSignatureDeserializer`.

The device-proxy test that uses a real WARP device was **SKIPPED** because no
WARP adapter exists under the cross-host runner. Real Windows D3D12 remains
NOT RUN. No Xbox console GPU behavior is claimed.

## 5. Tests run in 12C.14

| Test | Result | Scope |
|---|---|---|
| `xgameruntime` | PASS (106 checks) | offline initialization, threading/error/network/system/storage classes, `QueryApiImpl` behavior, host module handling |
| `xmem` | PASS (81 checks) | title-memory registration/query/alloc/free paths under the host |
| `pe_loader_bounds` | PASS (63 checks) | PE bounds and 12 directory-consistency fixtures |
| `dxgi_passthrough` | PASS (39 checks) | synthetic DXGI passthrough behavior |
| `winhttp_offline` | PASS (74 checks) | offline network failure behavior |

All were executed by the cross-host CTest suite under Wine. They are useful ABI
and offline-behavior evidence, but they are **not** native Windows tests and do
not prove GTA 6 compatibility.

## 6. ABI versus semantics

**ABI evidence available:** x64 COFF layout, export registration, specific
structure sizes and slot behavior exercised by synthetic tests, and the
`xgameruntime` check count.

**Not established:** that every Xbox structure has the correct size/alignment
for a real title, that every exception/error path matches GDK semantics, that
threading and memory behavior match console expectations, or that package/user/
store/save services behave as a title expects.

No authentication, entitlement, licensing, signature or DRM bypass was added.
Unexplained APIs remain `UNKNOWN`.

## 7. Required next evidence

On Windows, run the same tests natively and record the actual OS, ABI, VC++
runtime and failures. Then extend isolated synthetic fixtures for any API whose
signature is documented. Do not promote a stub to IMPLEMENTED without a test and
do not infer GTA 6 compatibility from the inventory.
