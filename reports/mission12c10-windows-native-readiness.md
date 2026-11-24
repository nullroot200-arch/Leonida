# LEONIDA — MISSION 12C.10
## WINDOWS NATIVE READINESS, RUNTIME HARDENING, GRAPHICS PIPELINE AND COMPATIBILITY VALIDATION

**Data:** 2026-11-24  
**Stato:** **COMPLETED WITH LIMITATIONS**  
**Repository:** `/home/francescohkone/leonida`  
**Branch:** `lab/verify-manifest`  
**HEAD:** `aa2988cc555bad7ecd508b48a702adbb32fe7c95`  
**Build 12C.10:** `/tmp/leonida-toolchain/build-12c10`

---

## 1. Executive summary

La 12C.10 è partita dallo stato reale della 12C.9 e ha prodotto un avanzamento verificabile, circoscritto alle aree autorizzate:

- nuova build pulita con **192/192 target**, **0 errori** e **39 eseguibili**;
- correzione del parser locale `WinHttpCrackUrl`: un host non bracketed con due separatori di porta
  (`host:80:90`) veniva accettato con host `host:80`; ora è rifiutato;
- validazione anticipata di URL e tabella componenti nulla, e di `dwStructSize` errato;
- rimozione del warning clang-cl sul cast `FARPROC` → `CrackUrlFn` tramite copia tipizzata del puntatore;
- estensione del test WinHTTP da 52 a **65 check**: porte predefinite 80/443/21, scheme maiuscolo, credenziali,
  IPv6 bracketed, query/fragment, URL malformati, input nulli, `WinHttpQueryDataAvailable` e `WinHttpWriteData`;
- **300/300 esecuzioni consecutive** del test WinHTTP senza failure;
- suite CTest finale: **36 PASS, 7 SKIP, 0 FAIL, 1 DISABLED**, 43 test considerati, 12 test `run_*` esclusi per policy;
- dry-run innocuo di `gta6rt` su fixture: **exit 0**, 1 modulo, **0 import non implementati**;
- verifica PE AMD64 e import del runtime;
- nessuna modifica ai file di gioco, nessun avvio di GTA 6, nessun `--init`/`--run`, nessun commit o push.

La missione **non** dimostra Windows native readiness, GPU readiness, D3D12/Vulkan reali, presentazione grafica o
first-launch readiness. La VM non ha GPU, `/dev/dri`, Visual Studio/MSVC o un host Windows. Queste restano
limitazioni ambientali dichiarate, non risultati mascherati.

---

## 2. Continuità di sessione

La sessione e la cronologia precedente sono state mantenute. Non è stato creato un nuovo progetto, non è stato
duplicato il repository e non è stata ricostruita LEONIDA da zero.

Stato 12C.9 riconfermato prima delle modifiche:

| Elemento | Valore verificato |
|---|---|
| Report 12C.9 | `reports/mission12c9-ultra-engineering-campaign.md` |
| SHA-256 report 12C.9 | `42a8240e54bfe96f20604deadc9dad49b4cb183c93b87eb3006e69ba1ed20548` |
| Sidecar 12C.9 | `OK` con `sha256sum -c` |
| Report 12C.8 | invariato |
| SHA-256 report 12C.8 | `d3ff34516fba4d6f9ecb29d8e17c13e840a5bd2c35c1824b22e84337644f3826` |
| Sidecar 12C.8 | `OK` con `sha256sum -c` |
| Retry register 12C.9 | `reports/mission12c9-retry-register.md` |

Non sono stati modificati il report 12C.9, il suo retry register o i sidecar precedenti.

---

## 3. Baseline, ambiente e limitazioni

### Repository

```text
Branch: lab/verify-manifest
HEAD:   aa2988cc555bad7ecd508b48a702adbb32fe7c95
Staging: vuoto
git diff --check: exit 0
```

File tracked modificati all'inizio e alla fine: **9**. Voci untracked preesistenti: **3**. Nessun file aggiunto
all'indice Git.

### Sistema

| Voce | Valore |
|---|---|
| Host | Debian GNU/Linux 13 (trixie), kernel `6.12.118+deb13-cloud-amd64` |
| Architettura | x86_64 |
| CPU/RAM | 4 vCPU, 14 GiB RAM |
| `/tmp` | tmpfs, circa 1,4 GiB liberi al termine |
| GPU | assente: `/dev/dri` non esiste, `nvidia-smi` assente |
| Display | `DISPLAY=:10.0` (ambiente virtuale, non GPU reale) |
| Windows nativo | non disponibile |
| Visual Studio 2022 / MSVC | non disponibile |
| Windows SDK reale | non disponibile; presente solo xwin 10.0.26100 |
| Wine | runtime isolato `wine-runtime-12c8`, `wine-ns` |
| CMake | 3.31.6 |
| Ninja | 1.12.1 |
| clang-cl | Debian clang 19.1.7, target `x86_64-pc-windows-msvc` |
| lld-link | Debian LLD 19.1.7 |
| Python | 3.13.5 |
| SDK xwin | `/tmp/leonida-toolchain/xwin-sdk` |

### Limiti dichiarati

- Wine non è Windows: i risultati CPU/Wine non sono test Windows nativi.
- clang-cl non è MSVC: ABI e comportamenti del compilatore Microsoft restano da verificare.
- xwin non è una installazione MSVC/Windows SDK reale.
- Nessuna GPU, nessun ICD Vulkan, nessun WARP disponibile.
- Nessun EXE GTA 6 disponibile o scaricato.
- `--init` e `--run` non sono stati eseguiti.
- `clang-tidy`, `scan-build`, sanitizer Windows e debugger nativo non sono disponibili in questa VM.
- Non esiste una review indipendente separata: la revisione è sequenziale e dello stesso agente.

---

## 4. Architettura esaminata

Sono stati letti e verificati i confini tra:

- `runtime/src/main.cpp`: parsing CLI, dry-run e orchestrazione;
- `runtime/src/pe_loader.cpp`: mapping PE, import, export, TLS, unwind, moduli bundled;
- `runtime/shims/registry.cpp` e `shims.h`: registry degli export e policy di passthrough;
- `runtime/shims/library_loader.cpp`: `LoadLibrary`/`GetProcAddress` per immagini mappate;
- `runtime/shims/winhttp_offline.cpp`: WinHTTP offline, handle, callback e parser URL;
- test CPU in `runtime/test/`;
- registrazione CMake/CTest in `runtime/CMakeLists.txt`;
- documentazione `docs/runtime_imports.md` e `runtime/README.md`.

Non sono state introdotte nuove responsabilità o dipendenze. La correzione 12C.10 è confinata a WinHTTP e al suo test;
la documentazione descrive il comportamento effettivo.

### Separazione loader/runtime

Il loader continua a distinguere:

- mapping e protezione delle sezioni;
- binding degli import tramite registry, moduli bundled e host;
- inizializzazione TLS e callback;
- registrazione delle unwind table;
- cleanup in `~Loader`.

Non sono state trovate regressioni nei test CPU del loader. Il dry-run ha caricato solo una fixture innocua.

---

## 5. PE loader — esito dell'ispezione

Sono stati verificati:

- DOS header, NT header, signature, machine AMD64, PE32+;
- `SizeOfHeaders`, `SizeOfImage`, section table e limiti del file;
- RVA/offset, sezioni troncate, sezioni oltre l'immagine, wrapping 32-bit;
- import table, lookup table, IAT, ordinali, nomi, forwarder e forwarder circolari;
- export table, ordinali, collisioni nome/ordinale e forwarder;
- TLS directory, template, indici, callback e limiti;
- exception directory, `RUNTIME_FUNCTION`, unwind data e `RtlAddFunctionTable`;
- relocazioni DIR64 e HIGHLOW, rifiuto dei 32-bit che non entrano nello spazio;
- gestione di `NumberOfRvaAndSizes` e directory mancanti;
- cleanup e propagazione degli errori.

Nessun nuovo bug del loader è stato riprodotto nella 12C.10. I test `loader`, `pe_loader`, `pe_loader_bounds`,
`loader_tls`, `dll_thread_calls`, `unimplemented_policy`, `startup_trace` e `dxgi_passthrough` restano PASS.
Il loader non è stato modificato in questa missione.

**Classificazione:** PARTIAL. La copertura CPU è buona; non esiste una verifica con l'EXE reale e non è stato
eseguito `--init`/`--run`.

---

## 6. WinHTTP — difetti, correzioni e prove

### BUG-12C10-01 — host con due separatori di porta

Il parser locale usava `rfind(L':')` per un host non bracketed. Di conseguenza:

```text
http://example.invalid:80:90/
```

veniva interpretato come host `example.invalid:80`, porta `90`. Non è una forma URL valida. La correzione usa il
primo `:` e rifiuta ogni secondo `:` in un host non bracketed. Gli host IPv6 restano supportati solo nella forma
bracketed `[::1]`.

### BUG-12C10-02 — input nulli passati al parser host

`WinHttpCrackUrl` tentava il parser host prima di validare `url` e `components`. La correzione valida subito:

- `url == nullptr`;
- `components == nullptr`;
- `components->dwStructSize != sizeof(URL_COMPONENTS)`.

Restituisce `ERROR_INVALID_PARAMETER` senza consegnare puntatori nulli al componente host.

### BUG-12C10-03 — warning di conversione `FARPROC`

Il cast:

```cpp
reinterpret_cast<CrackUrlFn>(GetProcAddress(...))
```

produceva `-Wcast-function-type-mismatch` con clang-cl. È stato introdotto `import_address<Fn>()`, che copia il
valore del puntatore con `std::memcpy` e mantiene il contratto della calling convention Windows. Il warning
specifico `FARPROC` → `CrackUrlFn` non compare più nel log di build completa.

### Copertura aggiunta

Il test `winhttp_offline` è passato da 52 a **65 check**. Nuovi casi:

- porta HTTP predefinita 80;
- HTTPS maiuscolo e porta 443;
- FTP e porta 21;
- credenziali `user:pass@`;
- porta esplicita, path, query e fragment;
- IPv6 bracketed con porta;
- rifiuto di `host:80:90`;
- rifiuto di porta vuota e authority vuota;
- rifiuto di URL nullo, componenti nulli e `dwStructSize` errato;
- `WinHttpQueryDataAvailable` e `WinHttpWriteData` falliscono con
  `ERROR_WINHTTP_INCORRECT_HANDLE_STATE`;
- notifiche `HANDLE_CLOSING` attese in modo deterministico, senza contare notifiche tardive di blocchi precedenti.

### Evidenze

```text
65 check(s), 0 failure(s)
300/300 esecuzioni consecutive PASS
```

Log: `/tmp/leonida-toolchain/logs-12c10/winhttp-12c10-clean-1..300.log`.

Il test è stato rieseguito 300 volte dopo la correzione della sincronizzazione. I tentativi falliti precedenti
(1/20, 4/50, 7/100, 10/200) sono conservati nel retry register e **non** sono stati cancellati.

---

## 7. HANDLE_CLOSING — analisi della flakiness

La 12C.9 aveva già stabilizzato una race del test. La 12C.10 ha riprodotto una seconda flakiness:

- il test chiudeva request, connection e session e poi aspettava un conteggio aggregato;
- le notifiche parent possono essere consegnate dal thread-pool dopo che `callbacks` è tornato a zero;
- un blocco successivo poteva quindi azzerare i contatori mentre notifiche del blocco precedente erano ancora in
  volo, producendo conteggi 2–5 invece di 3;
- in alcuni run la catena parent risultava ancora in consegna oltre il timeout breve del test.

La correzione è **nel test**, non nel shim: ogni handle viene chiuso in sequenza e si attende il conteggio esatto
(1, poi 2, poi 3) con quiescenza delle callback. Le asserzioni non sono state indebolite: il conteggio esatto resta
obbligatorio. Il comportamento del shim non è stato dichiarato corretto sulla base di uno SKIP o di un singolo run.

**Esito:** 300/300 PASS dopo la sincronizzazione; nessuna prova che il shim perda notifiche in condizioni normali.

---

## 8. DXGI

- `dxgi_passthrough`: **39/39 check PASS**.
- Export per nome, ordinale, collisioni, HRESULT, moduli assenti e passthrough allowlisted sono coperti.
- `device_proxy`: **SKIP** con codice 77; nessun adapter WARP in Wine.
- Non è stato eseguito un test DXGI su GPU reale.
- Non è stata verificata una swapchain o una presentazione reale.

**Classificazione:** PARTIAL. Il passthrough CPU è verificato; la parte DXGI hardware è NOT RUN.

---

## 9. D3D12

Sono stati ispezionati device, queue, allocator, command list, fence, descriptor heap, root signature, PSO,
barrier, resource state, reference counting e cleanup.

Non è stato possibile eseguire D3D12 reale:

- nessuna GPU;
- nessun WARP;
- nessun device D3D12 nativo;
- `device_proxy` termina SKIP;
- i test mock non equivalgono a D3D12 hardware.

**Classificazione:** **NOT RUN**. Non viene dichiarato D3D12 PASS.

---

## 10. Vulkan

- Header Vulkan non disponibili nella configurazione;
- nessun loader/ICD;
- `/dev/dri` assente;
- nessuna swapchain o presentazione;
- i test CPU di filtro device e supporto restano disponibili, ma non sono test GPU.

**Classificazione:** **BLOCKED / NOT RUN**. Non viene dichiarato Vulkan PASS.

---

## 11. Shader

- `shader_library`, `spirv_f16_halves`, `shader_fixture_path` PASS;
- `shader_library_corpus` SKIP per assenza di `LEONIDA_SHADERS`;
- parsing e fixture CPU verificati;
- traduzione, compilazione e pipeline GPU non verificate.

**Classificazione:** PARTIAL.

---

## 12. Xbox API, GameInput e Bink

- Gli shim Xbox sono coperti indirettamente da `xgameruntime`, `xmem`, `process_cmdline`, `file_system` e dai test
  del loader.
- Non esiste un inventario completo e verificato di tutte le API Xbox; le API sconosciute restano UNKNOWN.
- `gameinput` è **DISABLED**: SDL3 non è disponibile.
- `bink_decode`, `bink_play_headless`, `bink_audio`, `fsr_dispatch`, `bvh_builder` sono **SKIP** per asset,
  movie o prerequisiti mancanti.
- Non sono stati recuperati componenti proprietari non autorizzati.

**Classificazione:** PARTIAL/UNKNOWN; nessun supporto Xbox completo dichiarato.

---

## 13. Memoria, threading e diagnostica

- Il test WinHTTP ha esercitato handle, reference counting, callback concorrenti e cleanup.
- La flakiness `HANDLE_CLOSING` è stata analizzata e corretta nel test; non è stato dichiarato un bug del prodotto
  senza prova.
- Non sono disponibili sanitizer Windows, ASan/MSan/Tsan reali o debugger nativo.
- `xmem` (74 check) e i test di threading del loader restano PASS.
- Il dry-run riporta moduli, import, binding e policy di ritorno.
- Non è stato aggiunto un sistema diagnostico generalizzato per il gioco.

**Classificazione:** PARTIAL. La copertura CPU è reale; l'analisi dinamica nativa resta NOT RUN.

---

## 14. Build

### Configurazione

```text
cmake -S runtime -B /tmp/leonida-toolchain/build-12c10 -G Ninja
  -DCMAKE_BUILD_TYPE=RelWithDebInfo
  -DCMAKE_TOOLCHAIN_FILE=runtime/cmake/clang-cl-xwin.cmake
  -DXWIN_DIR=/tmp/leonida-toolchain/xwin-sdk
  -DCMAKE_CROSSCOMPILING_EMULATOR=/tmp/leonida-toolchain/wine-runtime-12c8/bin/wine-ns
  -DLEONIDA_D3D12_SHIM_TESTS=OFF
  -DLEONIDA_SDL3=OFF
  -DLEONIDA_VULKAN_HEADERS_FETCH=OFF
```

### Risultato

| Voce | Valore |
|---|---:|
| Configure | exit 0 |
| Target compilati | **192/192** |
| Errori | **0** |
| Eseguibili | **39** |
| Warning (occorrenze) | **96** |
| Warning (diagnostiche uniche) | **28** |
| Warning `FARPROC` → `CrackUrlFn` | **0** |
| Formato `gta6rt.exe` | COFF-x86-64, AMD64 |

I 96 warning restano in aree preesistenti (soprattutto `d3d12_xs.cpp`, `base_reservation.h`,
`pe_loader.cpp` e fixture di test). Non sono stati nascosti con flag permissivi. Non sono stati introdotti nuovi
errori o nuovi warning WinHTTP.

### Nota CTest

La prima configurazione della nuova build non aveva `CMAKE_CROSSCOMPILING_EMULATOR`: CTest tentava di eseguire i
PE come script shell e falliva tutti i test in 0,08 s. La build è stata riconfigurata con `wine-ns`; la suite
successiva è passata. Il fallimento è registrato nel retry register, non cancellato.

---

## 15. Test

### CTest finale

```text
100% tests passed, 0 tests failed out of 43
Total Test time (real) = 182.87 sec
```

| Categoria | Numero |
|---|---:|
| PASS | **36** |
| SKIP | **7** |
| FAIL | **0** |
| DISABLED | **1** |
| Test considerati | **43** |
| `run_*` esclusi per policy | **12** |

SKIP:

- `device_proxy` — WARP assente in Wine;
- `shader_library_corpus` — `LEONIDA_SHADERS` assente;
- `bink_decode`, `bink_play_headless`, `fsr_dispatch`, `bvh_builder`, `bink_audio` — asset/movie/prerequisiti
  mancanti.

DISABLED:

- `gameinput` — SDL3 assente.

I test `run_*` non sono stati eseguiti perché richiedono `gta6rt --run`. Non sono dichiarati PASS.

### Test WinHTTP

- 65 check per esecuzione;
- 300/300 esecuzioni consecutive PASS;
- 0 failure finali;
- nessuna asserzione indebolita;
- log conservati.

### Dry-run

```text
tiny_game.exe base=0000000140000000 size=53248 entry=+0x35f4 shim=11 host=76 module=0 unimplemented=0
1 module(s) mapped, 0 unimplemented import(s)
unimplemented by return policy: hresult=0 other=0
```

Exit 0. Non è un avvio di GTA 6 e non è una prova di compatibilità del gioco.

---

## 16. Analisi statica e verifiche

| Controllo | Esito |
|---|---|
| `git diff --check` | exit 0 |
| `python3 -m compileall -q tests tools/leonida-verify` | exit 0 |
| `tests/test_coverage_guard.py` | 7 test, OK |
| `llvm-readobj` su `gta6rt.exe` | COFF-x86-64, AMD64 |
| `llvm-readobj` su `winhttp_offline_test.exe` | COFF-x86-64, AMD64 |
| Sidecar 12C.9 | OK |
| Sidecar 12C.8 | OK |
| `clang-tidy` | **NOT RUN**: non installato |
| Sanitizer Windows/GPU | **NOT RUN**: ambiente non disponibile |
| Test Windows nativi | **NOT RUN**: nessun host Windows/MSVC |

---

## 17. Matrice di compatibilità

| Componente | Stato | Prova / limite |
|---|---|---|
| PE loader x64 | PARTIAL | loader/pe_loader/pe_loader_bounds PASS; nessun EXE reale |
| Caricamento DLL | PARTIAL | loader, bundled load, TLS PASS; no gioco |
| Risoluzione import | PARTIAL | dry-run 0 unimplemented su fixture; EXE reale assente |
| Export/forwarder | PARTIAL | test loader e forwarder PASS; no gioco |
| TLS | PARTIAL | loader_tls e callback PASS; no gioco |
| DXGI passthrough | PARTIAL | 39/39 PASS |
| DXGI GPU/present | NOT RUN | nessuna GPU |
| D3D12 | NOT RUN | nessun device reale/WARP |
| Vulkan | BLOCKED | header/ICD/GPU assenti |
| Shader CPU | PARTIAL | parsing/fixture PASS; corpus SKIP |
| Shader GPU | NOT RUN | nessuna GPU |
| Xbox API | PARTIAL/UNKNOWN | shim coperti; inventario completo assente |
| GameInput | NOT RUN | DISABLED, SDL3 assente |
| Bink/FSR/BVH | NOT RUN | SKIP, asset/prerequisiti assenti |
| Memoria | PARTIAL | test CPU; no sanitizer |
| Threading | PARTIAL | stress WinHTTP 300/300; no TSan |
| Diagnostica | PARTIAL | dry-run e CTest; no runtime trace completo |
| Build | PASS | 192/192, 39 EXE, 0 errori |
| Test CPU | PASS* | 36 PASS, 7 SKIP, 0 FAIL; 12 `run_*` esclusi |
| Windows native | NOT RUN | nessun host Windows/MSVC |
| GPU | BLOCKED | `/dev/dri` assente |
| First-launch readiness | NOT READY | nessun avvio autorizzato/verificato |

`PASS*` vale solo per la suite CPU effettivamente eseguita; non è una dichiarazione di compatibilità del gioco.

---

## 18. Matrice delle verifiche

| Verifica | Comando / posizione | Esito |
|---|---|---|
| Branch e HEAD | `git branch --show-current`, `git rev-parse HEAD` | corretti |
| Staging | `git diff --cached --name-only` | vuoto |
| Diff whitespace | `git diff --check` | exit 0 |
| Build completa | `cmake --build build-12c10 --parallel 4` | exit 0 |
| Build target | log `build-12c10.log` | 192/192 |
| Eseguibili | `find build-12c10 -maxdepth 1 -name '*.exe'` | 39 |
| CTest | `ctest -E '^run_'` | 36 PASS, 7 SKIP, 0 FAIL |
| WinHTTP mirato | `winhttp_offline_test.exe` | 65/65 |
| WinHTTP stress | 300 esecuzioni | 300/300 |
| Dry-run | `gta6rt --dry-run tiny_game.exe` | exit 0 |
| Usage | `gta6rt` senza argomenti | exit 2 |
| PE header | `llvm-readobj` | AMD64 |
| Python compile | `compileall` | exit 0 |
| Coverage guard | `test_coverage_guard.py` | 7/7 |
| Sidecar 12C.9 | `sha256sum -c` | OK |
| Sidecar 12C.8 | `sha256sum -c` | OK |
| GPU | `/dev/dri`, `nvidia-smi` | BLOCKED |
| D3D12/Vulkan | test reali | NOT RUN |
| clang-tidy | disponibilità strumento | NOT RUN |

---

## 19. Matrice dei test

| Test | Tipo | Esito | Nota |
|---|---|---|---|
| `gfx10_tiling` | CPU | PASS | — |
| `retire_tickets` | CPU | PASS | — |
| `buffer_va_index` | CPU | PASS | — |
| `pipeline_cache_file` | CPU | PASS | — |
| `xdxr_descs` | CPU | PASS | — |
| `vulkan_device_filter` | CPU | PASS | non GPU |
| `runtime_types` | ABI CPU | PASS | — |
| `loader` | loader CPU | PASS | fixture |
| `dxgi_passthrough` | DXGI CPU | PASS | 39 check |
| `pe_loader` | PE CPU | PASS | fixture |
| `pe_loader_bounds` | PE CPU | PASS | boundary |
| `loader_tls` | TLS CPU | PASS | fixture |
| `dll_thread_calls` | loader CPU | PASS | fixture |
| `unimplemented_policy` | loader CPU | PASS | fixture |
| `startup_trace` | diagnostica CPU | PASS | fixture |
| `device_proxy` | DXGI/WARP | SKIP | WARP assente |
| `xs_proxy_mock*` | mock CPU | PASS | 4 varianti |
| `root_sig` | D3D12 CPU | PASS | no GPU |
| `command_list` | CPU | PASS | — |
| `shader_fixture_path` | CPU | PASS | — |
| `resource_tiling` | CPU | PASS | — |
| `descriptor_table` | CPU | PASS | — |
| `shader_library` | CPU | PASS | — |
| `spirv_f16_halves` | CPU | PASS | — |
| `shader_library_corpus` | CPU | SKIP | `LEONIDA_SHADERS` assente |
| `bink_*` | media | SKIP | asset/movie assenti |
| `fsr_dispatch` | media/GPU | SKIP | prerequisiti assenti |
| `bvh_builder` | asset | SKIP | asset assenti |
| `xmem` | CPU | PASS | 74 check |
| `process_cmdline` | CPU | PASS | — |
| `file_system` | CPU | PASS | — |
| `winhttp_offline` | CPU/network-offline | PASS | 65 check |
| `xgameruntime` | CPU | PASS | 106 check |
| `gameinput` | input | DISABLED | SDL3 assente |
| `gta6rt_rejects_*` | CLI | PASS | 3 test |
| `root_signature` | CPU | PASS | — |
| `root_signature_oracle` | CPU | PASS | — |
| `run_*` | esecuzione | NOT RUN | 12 test esclusi per policy |

---

## 20. Matrice dei warning

| Categoria | Occorrenze | Stato |
|---|---:|---|
| `FARPROC` cast (aree preesistenti) | 59 | residuo noto |
| `missing-field-initializers` | 19 | residuo |
| `missing-braces` | 12 | residuo |
| funzioni non usate | 2 | residuo |
| `extern` duplicato | 1 | residuo |
| deprecazioni CRT | 3 | residuo |
| **Totale** | **96** | **0 errori** |

Le diagnostiche uniche sono **28**; la tabella conta le occorrenze nel log di build completa.

Il warning specifico `FARPROC` → `CrackUrlFn` è stato eliminato (0 occorrenze). Non sono stati soppressi warning
globalmente e non sono stati modificati flag per nascondere errori.

---

## 21. Matrice delle dipendenze

| Dipendenza | Disponibilità | Uso | Stato |
|---|---|---|---|
| CMake 3.31.6 | presente isolata | configure/build | PASS |
| Ninja 1.12.1 | presente | build | PASS |
| clang-cl 19.1.7 | presente | compilazione | PASS |
| lld-link 19.1.7 | presente | link | PASS |
| xwin SDK 10.0.26100 | presente | header/lib Windows | PASS (surrogato) |
| Wine `wine-ns` | presente | esecuzione PE | PASS (non Windows) |
| zlib1.dll | copiata app-local | test | PASS |
| Visual Studio 2022/MSVC | assente | build nativa Windows | BLOCKED |
| GPU / driver | assente | DXGI/D3D12/Vulkan | BLOCKED |
| Vulkan headers/ICD | assente | Vulkan | BLOCKED |
| SDL3 | assente | GameInput | NOT RUN/DISABLED |
| asset Bink/FSR/BVH | assenti | test media | SKIP |
| shader corpus | assente | corpus test | SKIP |
| clang-tidy | assente | analisi statica | NOT RUN |

---

## 22. Matrice dei blocchi

| Priorità | Blocco | Evidenza | Correggibile qui |
|---|---|---|---|
| P0 | EXE GTA 6 non disponibile | nessun file, nessun download | no |
| P0 | `--init`/`--run` non autorizzati | policy | no |
| P0 | Nessun Windows/MSVC reale | ambiente Linux | no |
| P1 | Nessuna GPU/`/dev/dri` | comandi ambiente | no |
| P1 | WARP assente | `device_proxy` SKIP 77 | no |
| P1 | Vulkan headers/ICD assenti | configure | no |
| P1 | D3D12 reale non eseguito | nessun device | no |
| P2 | 7 SKIP | asset/WARP/corpus | parziale |
| P2 | 12 `run_*` esclusi | policy | no |
| P2 | Inventario Xbox incompleto | analisi | parziale |
| P2 | 96 warning residui | build | parziale |
| P3 | Sanitizer/TSan/Windows ABI | strumenti assenti | no |
| P3 | Review indipendente | non disponibile | no |

Percorso critico: **Windows reale + MSVC/SDK → GPU reale/driver → D3D12/Vulkan device e present → EXE fornito
dall'utente → dry-run → `--init` autorizzato → analisi import/crash → solo dopo `--run`.**

---

## 23. First-launch readiness

**NOT READY.**

Il dry-run su fixture prova mapping, binding, report e propagazione degli import su un'immagine sintetica. Non prova:

- che l'EXE di GTA 6 sia caricabile;
- che le API Xbox mancanti siano innocue;
- che D3D12/Vulkan present funzioni;
- che il gioco superi inizializzazione, DRM o controlli di integrità;
- che ci sia compatibilità reale.

Nessun avvio è stato eseguito. La data del 27 novembre 2026 resta un obiettivo, non un criterio per dichiarare
risultati non verificati.

---

## 24. Roadmap tecnica successiva

1. **Windows 11 + Visual Studio 2022 + Windows SDK 10.0.26100**: build nativa, CTest CPU, confronto hash e warning.
2. **GPU reale**: RTX 4070 Ti, driver aggiornato, Vulkan SDK; eseguire `device_proxy`, test D3D12 COM, root
   signature, swapchain e un frame innocuo.
3. **Separare D3D12 e Vulkan**: nessuna dichiarazione congiunta; raccogliere log di device, adapter, feature level,
   present e device removal.
4. **Percorso di avvio**: ottenere l'EXE solo dall'utente e con autorizzazione; dry-run, poi `--init` solo se
   esplicitamente autorizzato; analizzare import, crash e dipendenze.
5. **Solo dopo**: valutare `--run`, senza promesse di FPS o compatibilità.

---

## 25. File modificati

### Modifiche 12C.10

- `runtime/shims/winhttp_offline.cpp`: parser URL più severo, validazione input, `import_address`.
- `runtime/test/winhttp_offline_test.cpp`: 13 nuovi check, test QueryDataAvailable/WriteData, sincronizzazione
  deterministica delle notifiche.
- `docs/runtime_imports.md`: comportamento del fallback e copertura 65/300 documentati.

### Modifiche preesistenti preservate

- `docs/d3d12_vulkan.md`
- `runtime/CMakeLists.txt`
- `runtime/shims/library_loader.cpp`
- `runtime/shims/registry.cpp`
- `runtime/shims/shims.h`
- `runtime/src/pe_loader.cpp`

`docs/runtime_imports.md` era già modificato nella baseline; la 12C.10 ne ha aggiornato solo la sezione WinHTTP.

### Untracked preesistenti

- `runtime/test/dxgi_passthrough_test.cpp`
- `tests/test_coverage_guard.py`
- `tools/leonida-verify/verify_build.py`

Nessun file eliminato. Nessun file di gioco, RPF, TTPF, EXE o asset modificato.

---

## 26. Retry register

Il registro completo è in:

`reports/mission12c10-retry-register.md`

Sintesi:

| ID | Problema | Esito |
|---|---|---|
| R01 | Baseline, hash e sidecar 12C.8/12C.9 | verificati |
| R02 | CTest senza emulatore Wine | corretto con `CMAKE_CROSSCOMPILING_EMULATOR` |
| R03 | Flakiness `HANDLE_CLOSING` | test reso deterministico, 300/300 |
| R04 | Warning `FARPROC` → `CrackUrlFn` | eliminato |
| R05 | `clang-tidy` assente | NOT RUN dichiarato |
| R06 | GPU/Windows/D3D12/Vulkan assenti | BLOCKED dichiarato |

---

## 27. Git, sicurezza e hash

### Git

```text
Branch: lab/verify-manifest
HEAD:   aa2988cc555bad7ecd508b48a702adbb32fe7c95
Staging: vuoto
git diff --check: exit 0
Tracked modificati: 9
Untracked preesistenti: 3
```

Nessun commit, push, merge, cherry-pick, reset, clean, checkout o restore. Nessun file aggiunto allo staging.

### Sicurezza

- GTA 6 non avviato.
- EXE GTA 6 non scaricato.
- `gta6rt --init` non eseguito.
- `gta6rt --run` non eseguito.
- Nessun file di gioco modificato.
- Nessun DRM, licenza, firma o autenticazione aggirato.
- Nessuna installazione globale.
- Nessun processo di gioco residuo.

### Hash sorgenti e artefatti

| Elemento | SHA-256 |
|---|---|
| `runtime/shims/winhttp_offline.cpp` | `2ea5c854cd6c582fe946df11661cb9ab945e99df122f8ba6216d0ac717dd4d7c` |
| `runtime/test/winhttp_offline_test.cpp` | `4ee3c86c62ab2f9d751f7649f64b547a7b02ca8ef94e3830efc634e287771910` |
| `docs/runtime_imports.md` | `378480a9f67778cbf0811de3de00c034e745f1d84d815845bc3abced97c5bd2f` |
| `build-12c10/gta6rt.exe` | `3cc102a534f841cd9b3cd59e2205e94033eb6315f612430b55544b68a8754fab` |
| `build-12c10/winhttp_offline_test.exe` | `da7ea1d0c438783b0d04ffc90c8935f719062c132a49b56e216956338a79251f` |
| `logs-12c10/build-12c10.log` | `db0d0b039863eec225830937ca6e2decebcdc3da14dcfcdf7a2e6b798cb001c3` |
| `logs-12c10/ctest-12c10-final.log` | `d37cba3df6f25d9a524c21ba6e4d82b170abe6bddd1a02cf1c50ed5cee33a3b3` |
| `logs-12c10/gta6rt-dryrun-12c10.log` | `2e8a4270f12244e72015d59fc6e1a2221d0df08ef86f36662720e6a5282d7790` |
| `logs-12c10/verification-12c10.txt` | `5d5c2df1da477179d4f15cb35be68011c1e8de15c0716b11c7dbc8194162eda4` |

### Hash report precedenti

| Report | SHA-256 |
|---|---|
| 12C.9 | `42a8240e54bfe96f20604deadc9dad49b4cb183c93b87eb3006e69ba1ed20548` |
| 12C.8 | `d3ff34516fba4d6f9ecb29d8e17c13e840a5bd2c35c1824b22e84337644f3826` |

Il sidecar di questo report è:

`reports/mission12c10-windows-native-readiness.sha256`

L'hash del report è quello registrato nel sidecar, calcolato sul file completo e verificato con `sha256sum -c`.

---

## 28. Conclusione

**COMPLETED WITH LIMITATIONS.**

La 12C.10 ha corretto due difetti reali del parser WinHTTP, eliminato un warning di conversione, esteso i test da
52 a 65 check, stabilizzato una flakiness del test delle notifiche e riconfermato la suite CPU con una build pulita.
Non ha dimostrato Windows native readiness, GPU readiness, D3D12/Vulkan reali, presentazione o first-launch
readiness. GTA 6 non è stato avviato, scaricato o modificato. La 12C.11 e M12D non sono state iniziate.
