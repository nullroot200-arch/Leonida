# LEONIDA — MISSION 12C.9 — RETRY AND RECOVERY REGISTER

**Stato: COMPLETED WITH LIMITATIONS**

Questo registro conserva i tentativi falliti e le correzioni applicate durante la campagna 12C.9. I log completi restano in `/tmp/leonida-toolchain/build-12c9/`.

## R01 — Configure senza `XWIN_DIR`

| Campo | Valore |
|---|---|
| ID | R01 |
| Fase | Configurazione build 12C9 |
| Comando | `cmake -S runtime -B /tmp/leonida-toolchain/build-12c9 ...` |
| Errore | `CMake Error at cmake/clang-cl-xwin.cmake:21: Set XWIN_DIR ...` |
| Causa | Il nuovo configure non ereditava la cache della build 12C7 |
| Primo tentativo | Configure senza `-DXWIN_DIR` → exit 1 |
| Correzione | Passare `-DXWIN_DIR=/tmp/leonida-toolchain/xwin-sdk` |
| Secondo tentativo | Configure con `XWIN_DIR`; mancava ancora il compilatore nel PATH |
| Esito finale | Configure exit 0 dopo R02 |
| Prova | `/tmp/leonida-toolchain/build-12c9/configure.log` e `reconfigure.log` |

## R02 — Compilatore e linker non nel `PATH`

| Campo | Valore |
|---|---|
| ID | R02 |
| Fase | Configurazione |
| Errore | `CMAKE_CXX_COMPILER not set` / strumenti clang-cl non trovati |
| Causa | I binari sono in `/tmp/leonida-toolchain/bin` e `/tmp/leonida-toolchain/llvm/usr/lib/llvm-19/bin`, non nel PATH globale |
| Primo tentativo | Path non esportato → configure fallito |
| Correzione | `export PATH=/tmp/leonida-toolchain/bin:/tmp/leonida-toolchain/llvm/usr/lib/llvm-19/bin:$PATH` |
| Secondo tentativo | Configure exit 0; compiler identificato come Clang 19.1.7 |
| Esito finale | PASS |
| Prova | `configure.log`, `CMakeCXXCompiler.cmake` |

## R03 — `zlib1.dll` assente nella build 12C9

| Campo | Valore |
|---|---|
| ID | R03 |
| Fase | Prima esecuzione CTest |
| Comando | CTest CPU su build 12C9 |
| Errore | 13 test FAIL; molti con output vuoto; `dxgi_passthrough` 9 FAIL; `gta6rt_rejects_*` senza usage |
| Causa | La build 12C9 non conteneva `zlib1.dll` app-local, presente nella build 12C7 |
| Primo tentativo | CTest completo → 30 PASS, 13 FAIL |
| Correzione | Copia di `/tmp/leonida-toolchain/build-12c7/zlib1.dll` nella directory temporanea 12C9 |
| Secondo tentativo | I test che fallivano per la DLL sono passati: `dxgi` 39/39, `root_sig`, `process_cmdline`, `xgameruntime`, `root_signature_oracle`, `gta6rt_rejects_*` |
| Esito finale | Risolto; nessuna modifica al repository |
| Prova | `/tmp/leonida-toolchain/build-12c9/zlib1.dll`, log CTest 12C9 |

## R04 — `WinHttpCrackUrl` fallisce in Wine

| Campo | Valore |
|---|---|
| ID | R04 |
| Fase | Test `winhttp_offline` |
| Comando | `wine-ns winhttp_offline_test.exe` / CTest `winhttp_offline` |
| Errore | `FAIL WinHttpCrackUrl parses a URL`; 1–4 FAIL per esecuzione |
| Causa | Il parser host `winhttp.dll` disponibile in Wine rifiutava un URL valido; lo shim delegava completamente al host |
| Primo tentativo | Nessuna patch: il test falliva stabilmente su CrackUrl |
| Correzione | Aggiunto parser locale http/https/ftp in `runtime/shims/winhttp_offline.cpp`; host preferito, fallback locale su host assente/rifiuto |
| Secondo tentativo | Errore di compilazione `INTERNET_SCHEME_DEFAULT` (vedi R05) |
| Terzo tentativo | Build exit 0; `WinHttpCrackUrl` 52/52 |
| Stress | 20 esecuzioni consecutive: **0 failure** |
| Esito finale | TEST PASS |
| Prova | `winhttp.final.1..20.log`; `winhttp_offline_test.exe` SHA-256 `883a29b5e499bd4a83ef4dd301d7e50f9eb5eb518a634450cad5855f708e90ba` |

## R05 — `INTERNET_SCHEME_DEFAULT` non dichiarato

| Campo | Valore |
|---|---|
| ID | R05 |
| Fase | Compilazione della patch R04 |
| Errore | `error: use of undeclared identifier 'INTERNET_SCHEME_DEFAULT'` |
| Causa | Il simbolo non è disponibile nella Windows SDK xwin 10.0.26100 |
| Primo tentativo | Build `winhttp_offline_test` → exit 1 |
| Correzione | Inizializzazione a `INTERNET_SCHEME_HTTP`, sempre sovrascritta dal parser per gli schemi accettati |
| Secondo tentativo | Build exit 0 |
| Esito finale | PASS |
| Prova | `build-winhttp2.log` |

## R06 — Race del test sulle notifiche `HANDLE_CLOSING`

| Campo | Valore |
|---|---|
| ID | R06 |
| Fase | Stress test `winhttp_offline` |
| Errore | `FAIL every handle reports HANDLE_CLOSING once` (2–4 FAIL su 5–15 esecuzioni) |
| Causa | Il test leggeva il contatore dentro il callback di chiusura, prima che il callback finisse e rilasciasse il parent; non era una notifica mancante del shim |
| Primo tentativo | Aggiunto contatore `callbacks`; la diagnostica ha mostrato `callbacks=1` e conteggio 1 dopo connection/session |
| Correzione | Spostata l'attesa di `callbacks == 0` prima del controllo; timeout del callback asincrono portato a 5 s; nessuna asserzione indebolita |
| Secondo tentativo | 20/20 esecuzioni PASS |
| Esito finale | TEST PASS |
| Prova | `winhttp.final.1..20.log` |

## R07 — `device_proxy` flaky nello stato Wine

| Campo | Valore |
|---|---|
| ID | R07 |
| Fase | CTest completo / test isolato |
| Comando | `ctest -R '^device_proxy$'` e suite completa |
| Errore | `FAIL DXGI factory created` / `FAILED (no DXGI factory)` nella suite; prima era SKIP 77 |
| Causa | Stato del wineserver/prefisso Wine dopo molte esecuzioni; non riproducibile come errore del proxy |
| Primo tentativo | Suite completa → FAIL |
| Correzione | `wineserver -k` sul runtime isolato, attesa 2 s |
| Secondo tentativo | Test isolato → `PASS DXGI factory created`, poi `SKIP ... no WARP adapter (0x80004001)`, exit 77 |
| Terzo tentativo | Suite completa finale → `device_proxy` **SKIP**, 0 FAIL |
| Esito finale | BLOCKED per WARP assente; SKIP corretto |
| Prova | `device_proxy.reset.log`, `ctest-final.log` |

## R08 — Launcher CTest Python senza modulo `cmake`

| Campo | Valore |
|---|---|
| ID | R08 |
| Fase | Verifica CTest |
| Errore | `ModuleNotFoundError: No module named 'cmake'` usando `pip-prefix/bin/ctest` |
| Causa | Wrapper Python del pacchetto CMake isolato; `PYTHONPATH` non include il sito |
| Primo tentativo | Wrapper → exit 1 |
| Correzione | Uso del binario reale `.../cmake/data/bin/ctest` |
| Secondo tentativo | `ctest --version` 3.31.6; `-N` exit 0 |
| Esito finale | PASS |
| Prova | `ctest-list-direct.log`, `ctest-final.log` |

## Registro sintetico

| ID | Errore | Correzione | Esito |
|---|---|---|---|
| R01 | `XWIN_DIR` mancante | variabile esplicita | PASS |
| R02 | compiler/linker fuori PATH | PATH isolato | PASS |
| R03 | `zlib1.dll` mancante | copia app-local temporanea | PASS |
| R04 | CrackUrl host fallisce in Wine | parser locale fallback | PASS, 20/20 |
| R05 | simbolo SDK inesistente | valore iniziale corretto | PASS |
| R06 | race conteggio chiusura | attesa quiescenza callback | PASS, 20/20 |
| R07 | device_proxy flaky Wine | wineserver reset | SKIP finale, WARP assente |
| R08 | wrapper CTest senza modulo | binario CMake diretto | PASS |

## Regola di retry applicata

Per ogni errore correggibile è stato eseguito il ciclo:

1. Esecuzione e log completo.
2. Identificazione dell'errore.
3. Analisi della causa.
4. Correzione autorizzata e circoscritta.
5. Ripetizione con condizioni modificate.
6. Verifica del risultato e delle regressioni.

Nessun test fallito è stato cancellato dalla cronologia. I test SKIP non sono stati dichiarati PASS.

## Limiti

- R07 non è una correzione del prodotto: è uno stato d'ambiente Wine.
- R04 è un fallback minimale, non una reimplementazione completa di WinHTTP.
- Non sono stati eseguiti test GPU, D3D12, Vulkan o avvio del gioco.
