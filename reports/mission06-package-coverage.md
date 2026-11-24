# LEONIDA — Mission 06 — Package Coverage Analysis

Data: 22 novembre 2026
Ambiente: VM Debian 13, 4 vCPU, 14 GiB RAM (nessun Windows, nessun toolchain MSVC)
Repository: `~/leonida`
Branch: `lab/verify-manifest` — HEAD `aa2988cc555bad7ecd508b48a702adbb32fe7c95`

## Baseline (Fase 1)

| Controllo | Esito |
|---|---|
| Branch | `lab/verify-manifest` |
| HEAD | `aa2988cc555bad7ecd508b48a702adbb32fe7c95` (atteso: coincide) |
| `git status --porcelain` | solo `?? tools/leonida-verify/` (artefatto Mission 04) |
| `git diff --stat` | vuoto — nessun file di codice modificato |
| Rapporto Mission 05 | presente, `reports/mission05-cpu-loader.md`, 20.765 byte |
| Report Mission 04 | presente, `reports/mission04-sha256.json`, 32.656 byte |
| Rete | nessuna richiesta effettuata |
| Build del gioco | mai aperta in scrittura; impronta `025d517b…6500ae2` invariata a fine lavoro |

Metodo: le 16 DLL sono state lette **solo** tramite `tools/pe_inspect.py` (apertura in lettura, parsing `struct`, nessuna terza parte). Nessuna DLL o EXE è stato caricato, eseguito o scritto. La classificazione degli import è stata poi calcolata confrontando l'output JSON del parser con le `SHIM_TABLE` dei sorgenti `runtime/shims/*.cpp`, la logica `Loader::resolve` / `prefer_host_copy` di `runtime/src/pe_loader.cpp` e `docs/runtime_imports.md`.

Artefatti intermedi (fuori dal repository, non versionati): `/tmp/m06/out/*.json`, `/tmp/m06/out/*.md`, `/tmp/m06/matrix.json`.

---

## 1. Inventario delle DLL

16 DLL, tutte già presenti nel pacchetto (`GTA6.Xbox.v1.0.2.1-CYBERLEEK`), tutte lette con successo dal parser: nessun errore di parsing.

| DLL | Byte | Macchina | Sottosistema | Image base | Size of image | Entry RVA | Sezioni | Export | Reloc | `.pdata` | TLS cb | Entropia max |
|---|---:|---|---|---|---:|---|---:|---:|---|---:|---:|---:|
| `Bink2Scarlett.dll` | 255.488 | x86-64 | GUI | `0x180000000` | 278.528 | `0x2ac1c` | 6 | 74 | sì | 527 | 0 | 7,558 |
| `XCurl.dll` | 199.152 | x86-64 | Console | `0x180000000` | 188.416 | `0x17b0` | 7 | 61 | sì | 446 | 0 | 6,381 |
| `XboxBvhBuilder.dll` | 884.224 | x86-64 | GUI | `0x180000000` | 909.312 | `0x227cc` | 7 | 12 | sì | 449 | 0 | 7,415 |
| `amd_fidelityfx_loader_xbox.dll` | 13.312 | x86-64 | Console | `0x180000000` | 32.768 | `0x18d0` | 6 | 5 | sì | 46 | 0 | 5,700 |
| `amd_fidelityfx_upscaler_xbox.dll` | 786.432 | x86-64 | Console | `0x180000000` | 802.816 | `0x26780` | 7 | 5 | sì | 477 | 0 | 6,870 |
| `concrt140.dll` | 298.992 | x86-64 | Console | `0x180000000` | 303.104 | `0x29160` | 6 | 291 | sì | 1.121 | 0 | 6,196 |
| `libHttpClient.GDK.dll` | 975.856 | x86-64 | GUI | `0x180000000` | 999.424 | `0x11f0` | 12 | 129 | sì | 2.452 | 0 | 5,642 |
| `msvcp140.dll` | 565.232 | x86-64 | Console | `0x180000000` | 577.536 | `0x525a0` | 6 | 1.493 | sì | 1.228 | 0 | 6,367 |
| `msvcp140_1.dll` | 26.104 | x86-64 | Console | `0x180000000` | 36.864 | `0x15c0` | 6 | 7 | sì | 45 | 0 | 5,771 |
| `msvcp140_2.dll` | 187.888 | x86-64 | Console | `0x180000000` | 192.512 | `0x1efa0` | 6 | 44 | sì | 469 | 0 | 6,297 |
| `msvcp140_atomic_wait.dll` | 57.312 | x86-64 | Console | `0x180000000` | 81.920 | `0x3c80` | 6 | 32 | sì | 86 | 0 | 6,121 |
| `msvcp140_codecvt_ids.dll` | 22.008 | x86-64 | Console | `0x180000000` | 28.672 | `0x1340` | 6 | 4 | sì | 32 | 0 | 5,677 |
| `vccorlib140.dll` | 336.888 | x86-64 | Console | `0x180000000` | 344.064 | `0x27e50` | 6 | 256 | sì | 697 | 0 | 6,220 |
| `vcomp140.dll` | 72.176 | x86-64 | GUI | `0x180000000` | 86.016 | `0x6580` | 6 | 113 | sì | 195 | 0 | 6,322 |
| `vcruntime140.dll` | 97.776 | x86-64 | Console | `0x180000000` | 110.592 | `0xf890` | 7 | 71 | sì | 236 | 0 | 6,445 |
| `vcruntime140_1.dll` | 37.848 | x86-64 | Console | `0x180000000` | 49.152 | `0x3e90` | 6 | 3 | sì | 79 | 0 | 6,271 |

Totale `.pdata`: 8.116 entry. Tutte le 16 immagini sono DLL (`is_dll = true`).

## 2. Architettura e caratteristiche PE

- **Una sola architettura**: `machine = x86-64` (AMD64) per tutte e 16; nessuna x86, ARM64 o altro. Coerente con il loader, che rifiuta ciò che non è AMD64.
- **Base preferita identica**: `0x180000000` per tutte, con `dynamic_base = true`. Le 16 immagini hanno una `.reloc` valida; il loader applica `DIR64`/`HIGHLOW`/`ABSOLUTE`, quindi il rebase è tecnicamente possibile, ma con `--game-dir` le immagini si mappano alla base preferita.
- **Sottosistema**: 12 immagini `Console` e 4 `GUI` (`Bink2Scarlett`, `XboxBvhBuilder`, `libHttpClient.GDK`, `vcomp140`). Il sottosistema non è usato dal loader per decidere nulla.
- **`.pdata` presente in tutte**: 8.116 entry totali, da 32 (`msvcp140_codecvt_ids`) a 2.452 (`libHttpClient.GDK`). È la ragione per cui `RtlAddFunctionTable` e `RtlPcToFileHeader` sono centrali per le eccezioni C++.
- **TLS**: `tls_callbacks = 0` per tutte. Solo `libHttpClient.GDK.dll` ha una sezione `.tls` (le altre immagini non ne hanno); quindi la TLS statica del pacchetto è un caso unico, non un pattern diffuso. La presenza di `.tls` senza callback è compatibile con dati TLS statici e `AddressOfIndex`; il loader inizializza la TLS e salta i callback perché la tabella è vuota — NON VERIFICATO a runtime su questa VM.
- **CFG**: solo `libHttpClient.GDK.dll` porta `.gfids` e `.00cfg`. Il loader non legge il Load Config e non registra la CFG: le bitmap sono inerti. Non è un errore di mapping, ma un percorso di protezione non riprodotto.
- **Sezioni non standard**: `.xbld` in 5 immagini (Bink, XCurl, XboxBvhBuilder, upscaler, libHttpClient), `.idata`/`.gfids`/`.00cfg`/`minATL`/`.tls` solo in `libHttpClient.GDK`, `_RDATA` in `vcruntime140`. `.xbld` è metadato di build Xbox, non necessario al mapping.
- **Entropia**: massimo 7,558 (`.data` di Bink) e 7,415 (`.rdata` di XboxBvhBuilder), ma il parser non marca alcuna sezione come cifrata (`looks_encrypted = false` per tutte). Le `.text` stanno tra ~5,6 e ~6,9: codice normale, non packato. Nessuna estrazione o decifratura è stata tentata.
- **Import per ordinale**: solo 3, tutti in immagini diverse: `Bink2Scarlett → XAudio2_9.dll!#1`, `vccorlib140 → OLEAUT32.dll!#4` e `#6`. Tutti gli altri import sono per nome.

## 3. Tabella degli import

Numeri complessivi:

| Metrica | Valore |
|---|---:|
| Immagini analizzate | 16 |
| Moduli importati distinti | 66 |
| Coppie (DLL, funzione) uniche | **611** |
| Import totali contando le occorrenze per immagine | **1.337** |
| Import serviti da SHIM | 58 unici / 112 occorrenze |
| Import serviti da HOST | 553 unici / 1.225 occorrenze |
| Import risolti da un modulo interno del pacchetto | 0 |
| Import non classificati | **0** |

Tabella per modulo importato (`img` = quante immagini lo importano; `func` = funzioni uniche; SHIM/HOST = classificazione statica, vedi §4):

| Modulo importato | img | func | SHIM | HOST |
|---|---:|---:|---:|---:|
| `advapi32.dll` | 1 | 8 | — | 8 |
| `api-ms-win-core-com-l1-1-0.dll` | 3 | 13 | — | 13 |
| `api-ms-win-core-console-l1-1-0.dll` | 1 | 1 | — | 1 |
| `api-ms-win-core-console-l2-1-0.dll` | 1 | 1 | — | 1 |
| `api-ms-win-core-console-l3-2-0.dll` | 1 | 1 | — | 1 |
| `api-ms-win-core-debug-l1-1-0.dll` | 12 | 4 | — | 4 |
| `api-ms-win-core-errorhandling-l1-1-0.dll` | 13 | 5 | — | 5 |
| `api-ms-win-core-errorhandling-l1-1-1.dll` | 1 | 2 | — | 2 |
| `api-ms-win-core-errorhandling-l1-1-2.dll` | 1 | 1 | — | 1 |
| `api-ms-win-core-fibers-l1-1-0.dll` | 4 | 4 | — | 4 |
| `api-ms-win-core-file-l1-1-0.dll` | 4 | 17 | 9 | 8 |
| `api-ms-win-core-file-l1-2-0.dll` | 2 | 2 | 1 | 1 |
| `api-ms-win-core-file-l2-1-0.dll` | 1 | 3 | 1 | 2 |
| `api-ms-win-core-handle-l1-1-0.dll` | 6 | 2 | — | 2 |
| `api-ms-win-core-heap-l1-1-0.dll` | 3 | 4 | — | 4 |
| `api-ms-win-core-heap-l2-1-0.dll` | 2 | 2 | — | 2 |
| `api-ms-win-core-interlocked-l1-1-0.dll` | 13 | 5 | — | 5 |
| `api-ms-win-core-libraryloader-l1-2-0.dll` | 13 | 11 | 7 | 4 |
| `api-ms-win-core-libraryloader-l1-2-1.dll` | 2 | 2 | 2 | — |
| `api-ms-win-core-localization-l1-2-0.dll` | 4 | 5 | — | 5 |
| `api-ms-win-core-localization-obsolete-l1-2-0.dll` | 1 | 1 | — | 1 |
| `api-ms-win-core-processenvironment-l1-1-0.dll` | 2 | 4 | — | 4 |
| `api-ms-win-core-processthreads-l1-1-0.dll` | 15 | 21 | 1 | 20 |
| `api-ms-win-core-processthreads-l1-1-1.dll` | 13 | 2 | — | 2 |
| `api-ms-win-core-processtopology-obsolete-l1-1-0.dll` | 1 | 1 | — | 1 |
| `api-ms-win-core-profile-l1-1-0.dll` | 15 | 2 | — | 2 |
| `api-ms-win-core-psm-appnotify-l1-1-0.dll` | 1 | 2 | — | 2 |
| `api-ms-win-core-registry-l1-1-0.dll` | 2 | 3 | — | 3 |
| `api-ms-win-core-registry-l2-1-0.dll` | 1 | 1 | — | 1 |
| `api-ms-win-core-rtlsupport-l1-1-0.dll` | 13 | 7 | — | 7 |
| `api-ms-win-core-string-l1-1-0.dll` | 5 | 5 | — | 5 |
| `api-ms-win-core-string-obsolete-l1-1-0.dll` | 1 | 2 | — | 2 |
| `api-ms-win-core-synch-l1-1-0.dll` | 11 | 25 | — | 25 |
| `api-ms-win-core-synch-l1-2-0.dll` | 8 | 10 | — | 10 |
| `api-ms-win-core-synch-l1-2-1.dll` | 1 | 1 | — | 1 |
| `api-ms-win-core-sysinfo-l1-1-0.dll` | 15 | 5 | — | 5 |
| `api-ms-win-core-sysinfo-l1-2-0.dll` | 3 | 2 | — | 2 |
| `api-ms-win-core-threadpool-l1-2-0.dll` | 4 | 15 | — | 15 |
| `api-ms-win-core-threadpool-legacy-l1-1-0.dll` | 1 | 1 | — | 1 |
| `api-ms-win-core-util-l1-1-0.dll` | 7 | 2 | — | 2 |
| `api-ms-win-core-winrt-error-l1-1-0.dll` | 1 | 4 | — | 4 |
| `api-ms-win-core-winrt-l1-1-0.dll` | 1 | 8 | — | 8 |
| `api-ms-win-core-winrt-string-l1-1-0.dll` | 1 | 9 | — | 9 |
| `api-ms-win-crt-convert-l1-1-0.dll` | 6 | 14 | — | 14 |
| `api-ms-win-crt-environment-l1-1-0.dll` | 2 | 2 | — | 2 |
| `api-ms-win-crt-filesystem-l1-1-0.dll` | 1 | 6 | — | 6 |
| `api-ms-win-crt-heap-l1-1-0.dll` | 13 | 10 | — | 10 |
| `api-ms-win-crt-locale-l1-1-0.dll` | 3 | 9 | — | 9 |
| `api-ms-win-crt-math-l1-1-0.dll` | 6 | 28 | — | 28 |
| `api-ms-win-crt-runtime-l1-1-0.dll` | 15 | 26 | 5 | 21 |
| `api-ms-win-crt-stdio-l1-1-0.dll` | 10 | 38 | — | 38 |
| `api-ms-win-crt-string-l1-1-0.dll` | 11 | 30 | — | 30 |
| `api-ms-win-crt-time-l1-1-0.dll` | 2 | 9 | — | 9 |
| `api-ms-win-crt-utility-l1-1-0.dll` | 1 | 1 | — | 1 |
| `api-ms-win-eventing-classicprovider-l1-1-0.dll` | 1 | 6 | — | 6 |
| `api-ms-win-eventing-provider-l1-1-0.dll` | 1 | 4 | — | 4 |
| `crypt32.dll` | 2 | 8 | — | 8 |
| `d3d12_xs.dll` | 2 | 2 | **2** | — |
| `kernel32.dll` | 1 | 56 | 10 | 46 |
| `msvcp140.dll` | 8 | 88 | — | 88 |
| `oleaut32.dll` | 1 | 2 | — | 2 |
| `vcruntime140.dll` | 14 | 24 | — | 24 |
| `vcruntime140_1.dll` | 8 | 1 | — | 1 |
| `winhttp.dll` | 2 | 16 | **16** | — |
| `xaudio2_9.dll` | 1 | 1 | — | 1 |
| `xmem.dll` | 3 | 4 | **4** | — |

Import per immagine (occorrenze):

| Immagine | Moduli | Import | SHIM | HOST |
|---|---:|---:|---:|---:|
| `Bink2Scarlett.dll` | 20 | 60 | 4 | 56 |
| `XCurl.dll` | 33 | 140 | 24 | 116 |
| `XboxBvhBuilder.dll` | 21 | 57 | 4 | 53 |
| `amd_fidelityfx_loader_xbox.dll` | 9 | 22 | 5 | 17 |
| `amd_fidelityfx_upscaler_xbox.dll` | 24 | 86 | 6 | 80 |
| `concrt140.dll` | 23 | 103 | 2 | 101 |
| `libHttpClient.GDK.dll` | 14 | 198 | 26 | 172 |
| `msvcp140.dll` | 34 | 187 | 13 | 174 |
| `msvcp140_1.dll` | 13 | 33 | 2 | 31 |
| `msvcp140_2.dll` | 18 | 96 | 2 | 94 |
| `msvcp140_atomic_wait.dll` | 20 | 64 | 4 | 60 |
| `msvcp140_codecvt_ids.dll` | 11 | 24 | 2 | 22 |
| `vccorlib140.dll` | 27 | 114 | 7 | 107 |
| `vcomp140.dll` | 29 | 78 | 7 | 71 |
| `vcruntime140.dll` | 16 | 41 | 3 | 38 |
| `vcruntime140_1.dll` | 13 | 34 | 1 | 33 |

**Nessuna DLL del pacchetto importa un'altra DLL del pacchetto.** La colonna "MODULO INTERNO" è quindi 0 nel pacchetto: le 16 immagini si appoggiano solo a shim, host e CRT. Il percorso `Binding::Module` resta rilevante solo per l'EXE (assente), che importerà verosimilmente `Bink2Scarlett.dll`, `XboxBvhBuilder.dll`, le FidelityFX e i CRT.

## 4. Copertura degli shim

Le `SHIM_TABLE` espanse dalle macro (`FILE_API`, `UCRT`, `LOADER`, `TITLE_VIRTUAL_ALLOC`, `COMMAND_LINE`, `EXIT_PROCESS`, `XGR`) registrano **365 voci** su 29 chiavi DLL. Il pacchetto ne usa **58** (112 occorrenze); **307 sono registrate ma non usate da nessuna delle 16 DLL** — sono shim destinati all'EXE o a moduli non ancora presenti.

Copertura dei sei import specifici Xbox (gli unici non desktop):

| Consumatore | Import | Binding |
|---|---|---|
| `Bink2Scarlett.dll` | `xmem.dll!XMemAlloc`, `XMemFree` | SHIM (`runtime/shims/xmem.cpp`) |
| `XboxBvhBuilder.dll` | `xmem.dll!XMemVirtualQuery` | SHIM (`xmem.cpp:40`) |
| `XboxBvhBuilder.dll` | `d3d12_xs.dll!D3D12SerializeVersionedRootSignature` | SHIM (`d3d12_xs.cpp:56`) |
| `amd_fidelityfx_upscaler_xbox.dll` | `xmem.dll!XMemAlloc`, `XMemFree`, `XMemGetWorkingSetStatistics` | SHIM (`xmem.cpp`) |
| `amd_fidelityfx_upscaler_xbox.dll` | `d3d12_xs.dll!D3D12CreateRootSignatureDeserializer` | SHIM (`d3d12_xs.cpp:106`) |

Altri gruppi interamente coperti da shim:

- **WinHTTP**: 16/16 funzioni usate da `XCurl` e `libHttpClient` sono in `winhttp_offline.cpp` (offline per progetto: `SendRequest` fallisce con `ERROR_WINHTTP_CANNOT_CONNECT`).
- **Library loader**: 9 funzioni registrate per 7 chiavi; il pacchetto ne usa tutte e 9 (`LoadLibraryA/W/ExA/ExW`, `GetModuleHandleA/W`, `GetProcAddress`, `FreeLibrary`, `DisableThreadLibraryCalls`) su `api-ms-win-core-libraryloader-l1-2-0/1` e `kernel32`.
- **File system**: 12 funzioni file (`CreateFileW/A`, `CreateFile2`, `CreateDirectoryW`, `FindFirstFileW/ExW`, `FindNextFileW`, `FindClose`, `GetFileAttributesW/ExW`, `SetFileAttributesW`, `CopyFile2`) usate da `msvcp140`, `XCurl`, `libHttpClient`, `vcomp140`, `Bink` — tutte instradate all'overlay `GAME:`.
- **Process/CRT**: `ExitProcess`, `abort`, `_configure_narrow_argv`, `_configure_wide_argv`, `__p___argc`, `__p___wargv` coperti da `process.cpp`.
- **`kernel32.dll`**: 10 shim su 56 import (i restanti 46 sono host), tutti di file/loader/processo.

**Disallineamento con `docs/runtime_imports.md`.** La tabella "Measured result" del documento non corrisponde più al codice a HEAD per 4 immagini: i conteggi statici danno `Bink2Scarlett` 4/56 (doc 3/57), `XCurl` 24/116 (doc 9/131), `libHttpClient.GDK` 26/172 (doc 11/187), `msvcp140` 13/174 (doc 9/178). Le altre 12 coincidono esattamente. La causa è l'aggiunta successiva degli shim `library_loader`, `file_system`, `process` e `winhttp` (il testo del documento la cita, la tabella no). È un drift documentale, non un difetto del loader: la classificazione statica qui sopra è quella del codice a HEAD.

## 5. Funzioni non classificate

**Nessuna.** Tutte le 611 coppie (DLL, funzione) ricadono in una categoria:

- 58 SHIM IMPLEMENTATO (tabella sopra e §4);
- 553 HOST IMPLEMENTATO: DLL di sistema Windows o API set (`api-ms-win-*`) risolti da `LoadLibraryExA(..., LOAD_LIBRARY_SEARCH_SYSTEM32)` + `GetProcAddress` in `Loader::resolve` (`runtime/src/pe_loader.cpp:1095-1130`);
- 0 MODULO INTERNO (nessuna dipendenza tra DLL del pacchetto);
- 0 STUB/NON IMPLEMENTATO nel senso di "import senza binding": ogni import ha un percorso di risoluzione. Gli stub parziali (funzioni che rispondono `E_NOTIMPL`) sono elencati in §6, ma non sono import non risolti.

Casi che richiedono una nota, non una nuova categoria:

- **CRT del pacchetto**: `msvcp140`, `vcruntime140`, `vcruntime140_1` sono importati da 8–14 immagini, ma `prefer_host_copy` (`pe_loader.cpp:453`) fa preferire le copie host dei 10 nomi CRT. La classificazione "HOST" è quindi quella che il loader applicherà davvero; le immagini CRT del pacchetto si mappano solo nei test. Questo è coerente con il documento, ma significa che la matrice non misura l'uso delle CRT Xbox incluse.
- **API set**: la presenza effettiva di ogni `api-ms-win-*` su Windows 10/11 non è verificabile da Debian. Sono trattati come HOST per costruzione del loader; un set assente su una specifica build di Windows produrrebbe un import unimplemented a runtime.
- **`msvcp140.dll` importato da `msvcp140_1/_2/_atomic_wait/_codecvt_ids`**: come sopra, il loader preferisce la CRT host, quindi il grafo interno alle CRT non viene esercitato.
- **Ordinali**: `XAudio2_9!#1`, `OLEAUT32!#4`, `OLEAUT32!#6` sono risolti per ordinale dall'host; il nome non è noto dal solo import table e non è stato dedotto.

## 6. Lacune e priorità (Fase 4)

Nessuna API è stata implementata. "Parziale" significa: la funzione esiste ed è registrata, ma il codice restituisce `E_NOTIMPL`, copre solo una parte misurata della struttura, o non è raggiunta dal pacchetto.

| # | DLL che la richiede | Funzione / percorso | Modulo LEONIDA | Motivazione priorità | Evidenza nel codice |
|---|---|---|---|---|---|
| 1 | `libHttpClient.GDK.dll` (30 thunk `XPackage*`) | classe `XPackageImpl` (`IXPackageImpl3`, slot 3-40) | `runtime/shims/xgameruntime.cpp` | ALTA: `libHttpClient` chiama 30 thunk di questa classe; oggi `QueryApiImpl` risponde `0x80070032` (classe non registrata) e il primo boot perderebbe identità/mount del package, usati dall'HTTP GDK | `xgameruntime.cpp` (tabella classi: XPackage "not served yet" in `docs/runtime_imports.md`); `QueryApiImpl` → `0x80070032` per classi non servite |
| 2 | `libHttpClient.GDK.dll` via `IXPersistentLocalStorageImpl3` | `XPersistentLocalStorageMountForPackage` | `xgameruntime.cpp` | MEDIA: unico slot della classe che risponde `E_NOTIMPL`; gli altri 5 slot sono serviti offline | `pls_mount_for_package` → `*mount_handle = nullptr; return E_NOTIMPL;` (`xgameruntime.cpp ~452-461`) |
| 3 | `XCurl.dll` via `IXNetworkingImpl2` | 3 aggiunte di `IXNetworkingImpl2` (slot 18-20) | `xgameruntime.cpp` | MEDIA: `net_not_implemented` risponde `E_NOTIMPL`; le funzioni base della rete sono già offline | `net_not_implemented` (`xgameruntime.cpp:324`), vtable `kNetworkingVtable` |
| 4 | `XboxBvhBuilder.dll`, `amd_fidelityfx_upscaler_xbox.dll` (via device Xbox) | slot del device oltre la vtable PC / non misurati (`PresentX`, `SuspendX`, `ResumeX`, …) | `runtime/shims/d3d12_xs_device.cpp` | MEDIA: il proxy Xbox copre solo gli slot misurati; gli altri tornano `E_NOTIMPL` e sono loggati una volta | `d3d12_xs_device.cpp:737`, `:860-869`; commento `d3d12_xs.cpp:6` ("only the measured slots are overridden") |
| 5 | percorso D3D12/DXGI (EXE, non nel pacchetto) | `IDXGIFactory::CreateSoftwareAdapter`, `GetSharedResourceAdapterLuid`, `RegisterStereoStatusWindow/Event` | `runtime/shims/dxgi_com.cpp` | BASSA/MEDIA: `E_NOTIMPL` espliciti; irraggiungibili finché manca l'EXE, ma il primo device creation può passarci | `dxgi_com.cpp:868`, `:927-929` |
| 6 | `amd_fidelityfx_upscaler_xbox.dll` | `XMemGetWorkingSetStatistics` | `runtime/shims/xmem.cpp` | BASSA: parziale **per misura**, non per pigrizia — scrive solo 16 byte su un buffer da 0x80, con il working set a +8; il resto è sconosciuto e azzerato | `xmem.cpp:60-90` (commento sui 7 call site, offset misurati) |
| 7 | `XboxBvhBuilder.dll` | `XMemVirtualQuery` | `xmem.cpp` | BASSA: i campi oltre `MEMORY_BASIC_INFORMATION` sono sconosciuti e azzerati; i chiamanti testano solo il successo | `xmem.cpp:34-58` (avviso a runtime, output 64 byte) |
| 8 | EXE (assente) | qualunque import non coperto | `runtime/src/pe_loader.cpp` + `registry.cpp` | ALTA ma **bloccata**: senza EXE non si conosce la superficie import; la policy `LEONIDA_UNIMPLEMENTED=log/fail/stop` è pronta e il dry-run conterà gli import mancanti | `registry.cpp:159-213`; `docs/runtime_imports.md` §"When an unimplemented import is called" |
| 9 | `Bink2Scarlett.dll` | `XAudio2_9.dll!#1` | host (nessuno shim) | BASSA: audio via host XAudio2.9; percorso mai esercitato (nessuna esecuzione) | import ordinale misurato; nessuna voce in `runtime/shims/` |
| 10 | `libHttpClient.GDK.dll` | CFG (`.gfids`/`.00cfg`) | `pe_loader.cpp` | BASSA: il loader non registra la CFG; le bitmap restano inerti. Non impedisce il mapping | sezioni `.gfids`/`.00cfg` presenti solo in `libHttpClient.GDK`; nessun Load Config nel loader |
| 11 | `D3D12XboxCreateDevice` | creatore device Xbox | `d3d12_xs.cpp:124` | MEDIA: registrato ma **non importato da nessuna DLL del pacchetto**; sarà il primo percorso dell'EXE e non è coperto dalla matrice | `SHIM_TABLE(d3d12_xs, …)` contiene la voce; nessun import la referenzia (307 voci non usate) |

Nota su WinHTTP: le 16 funzioni sono coperte, ma la copertura è **offline per progetto**. Non è una lacuna da colmare in questa fase: qualunque funzionalità online del titolo fallirà con `ERROR_WINHTTP_CANNOT_CONNECT`, come documentato.

## 7. Limiti dell'analisi

- **Solo statica**: nessuna DLL è stata caricata, mappata o eseguita. "SHIM IMPLEMENTATO" significa "la voce esiste nella tabella e il codice che la implementa è presente", non "la funzione si comporta correttamente".
- **Nessun Windows**: la classificazione HOST non è verificata; la presenza degli API set su una build Windows specifica è assunta. Non è stato possibile eseguire `gta6rt --dry-run`.
- **EXE assente**: la matrice copre 16 DLL su 17 PE attesi. Gli import dell'eseguibile — la parte che conta di più per il primo boot — restano ignoti.
- **Parser euristico**: `pe_inspect.py` marca `where = shim` ogni DLL che non risolve come API set *su questa macchina*, quindi il campo `where` del parser non è la classificazione della matrice; la matrice è stata ricalcolata dalle `SHIM_TABLE` e da `prefer_host_copy`. L'espansione delle macro è testuale: una futura macro non riconosciuta farebbe sottostimare gli shim (qui le 7 macro note coprono tutte le tabelle).
- **Drift documentale**: `docs/runtime_imports.md` è affidabile per la prosa e per 12 immagini su 16, ma la sua tabella "Measured result" è precedente agli shim loader/file/process/winhttp. I numeri di questo rapporto sono quelli del codice a HEAD.
- **Export non risolti**: sono stati contati (es. 1.493 in `msvcp140`), ma non è stato verificato che le funzioni esportate siano richieste o corrette.
- **Caricamenti runtime invisibili**: `libHttpClient` e `XCurl` caricano `xgameruntime.dll` con `LoadLibrary`/`GetProcAddress` (stringhe, non import table). Il parser riporta `runtime_load_candidates = 0`, quindi questa parte è fuori dalla matrice e resta documentata solo in `docs/runtime_imports.md`.
- **Nessuna decifratura**: nessuna sezione è risultata cifrata; non è stato tentato nulla di diverso dal parsing.
- **Regole rispettate**: nessuna modifica al gioco, nessuna esecuzione di DLL/EXE, nessuna estrazione, nessuna installazione, nessun `sudo`, nessun download, nessuna build, nessuna modifica al codice LEONIDA, nessun commit.

## 8. Proposta Missione 07

**Mission 07 — Copertura inversa e guardia anti-drift.**

Obiettivo: rendere ripetibile e verificabile ciò che questa missione ha misurato a mano, senza toccare il loader né richiedere Windows.

1. **Test di coerenza documentale** (Python, fixture = output JSON già prodotto dal parser, nessuna DLL reale nei test): data una tabella di import e le `SHIM_TABLE`, ricalcolare shim/host per immagine e fallire se `docs/runtime_imports.md` diverge. Oggi fallirebbe su 4 immagini: è esattamente il drift trovato in §4.
2. **Copertura inversa**: elencare le 307 voci di shim non usate dal pacchetto, raggruppate per modulo (`xgameruntime`, `gameinput`, `d3d12_xs`, file system, loader), come "superficie pronta per l'EXE". Serve a distinguere "shim scritto e mai esercitato" da "shim mancante".
3. **Matrice delle classi GDK**: incrociare i 30 thunk `XPackage*` di `libHttpClient` con gli slot `XPackageImpl` non serviti (priorità #1 di §6), producendo l'elenco ordinato degli slot da implementare e dei test sintetici da scrivere — senza implementarli in Mission 07.
4. **Criterio di uscita**: rapporto `reports/mission07-coverage-guard.md` con il test eseguito (solo Python, `TemporaryDirectory`), l'elenco delle divergenze e la lista prioritaria; nessuna modifica a `pe_loader`, shim o build.

Alternativa più ambiziosa, da valutare solo se l'utente fornisce un ambiente Windows: rieseguire `gta6rt --dry-run` sulle 16 DLL e sostituire la classificazione statica con quella misurata, chiudendo il limite principale di §7.

---

### Appendice — Riproduzione

```bash
PKG=/home/francescohkone/Downloads/GTA6.Xbox.v1.0.2.1-CYBERLEEK
python3 -I tools/pe_inspect.py $(find "$PKG" -type f -iname '*.dll' | sort) --out /tmp/m06/out
```

Classificazione: JSON del parser × `SHIM_TABLE` espanse × `prefer_host_copy` (`runtime/src/pe_loader.cpp:453`) × `Loader::resolve` (`:1095`). Le 16 DLL sono state aperte in sola lettura; nessun file del pacchetto è stato modificato.
