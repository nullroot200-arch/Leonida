# LEONIDA — MISSION 12C.4 — WINDOWS/MSVC VERIFICATION & GIT TRACEABILITY CLOSURE

Data: 23 novembre 2026. Verifica delle limitazioni della Missione 12C.3. Nessuna implementazione M12D, nessun commit,
nessun push, nessuno staging, nessuna modifica alle aree protette. Il rapporto 12C.3 e stato letto integralmente.

**Stato: COMPLETED WITH LIMITATIONS.** La verifica Windows/MSVC e BLOCKED: questa macchina e Linux e non dispone di
CMake, MSVC, Windows SDK, Wine o MinGW. La tracciabilita Git del test DXGI non e chiusa perche la missione vieta
`git add` e `git commit`; il piano di commit e documentato, ma non eseguito. M12D non e autorizzato.

---

## A. Stato iniziale Git

| Voce | Valore |
|---|---|
| Repository | `~/leonida` |
| Branch | `lab/verify-manifest` |
| HEAD | `aa2988cc555bad7ecd508b48a702adbb32fe7c95` |
| Rapporto precedente | `reports/mission12c3-dxgi-loader-safety.md` |
| SHA-256 M12C.3 | `b7715984c771eeb062f1df6473b0ad1498ce9b15f513b2fa90a1703abd2b5fe0` |
| Hash normalizzato M12C.3 | `db5c85fc44b538c10e2d3207db63c7c3ade2346a429cf120cda33d02ea86fa56` |

Lo stato Git iniziale, invariato rispetto alla M12C.3:

```text
 M docs/d3d12_vulkan.md
 M docs/runtime_imports.md
 M runtime/CMakeLists.txt
 M runtime/shims/library_loader.cpp
 M runtime/shims/registry.cpp
 M runtime/shims/shims.h
 M runtime/src/pe_loader.cpp
?? runtime/test/dxgi_passthrough_test.cpp
?? tests/test_coverage_guard.py
?? tools/leonida-verify/verify_build.py
```

`git diff --stat` riportava 7 file modificati, 404 inserimenti e 48 rimozioni. `git diff --check` era pulito. Il test
DXGI e ancora untracked; `git check-ignore -v runtime/test/dxgi_passthrough_test.cpp` risponde che **non e ignorato**.
Il file e assente dall'indice, quindi comparira come `??` finche non viene aggiunto con una decisione esplicita.

Le aree protette non risultano modificate:

```text
git diff --quiet -- runtime/shims/d3d12_vulkan_device.cpp runtime/shims/d3d12_xs.cpp \
    runtime/shims/dxgi_com.cpp runtime/shims/dxgi_swapchain.h
exit 0
```

Nessuna modifica alla cronologia, nessun reset, clean, checkout distruttivo o stash.

---

## B. Ambiente Windows/MSVC disponibile

La macchina e:

```text
Linux security-lab 6.12.118+deb13-cloud-amd64 #1 SMP PREEMPT_DYNAMIC Debian 6.12.118-1
x86_64 GNU/Linux
```

Controllo dei comandi:

| Requisito | Esito |
|---|---|
| Windows x64 | ASSENTE: sistema Linux |
| Visual Studio C++ Build Tools | ASSENTE |
| MSVC `cl` | ASSENTE |
| `msbuild` / `devenv` | ASSENTI |
| Windows SDK / `windows.h` | ASSENTE |
| CMake | ASSENTE |
| CTest | ASSENTE |
| Wine / Wine64 | ASSENTE |
| MinGW (`x86_64-w64-mingw32-g++`) | ASSENTE |
| clang++ | ASSENTE |
| PowerShell / cmd.exe | ASSENTI |
| g++ | PRESENTE: `/usr/bin/g++` |
| Python 3 | PRESENTE, usato per i controlli degli script |

`g++` non e MSVC e non dispone degli header Windows: non e stato usato per simulare una build Windows. Non esiste un
secondo host Windows raggiungibile da questa sessione.

---

## C. Comandi realmente eseguiti

### C.1 Configurazione e build

I comandi della sezione I del rapporto 12C.3 sono stati tentati nella forma documentata:

```text
cmake -S runtime -B runtime/build/windows -G "Visual Studio 17 2022" -A x64
bash: line 4: cmake: command not found
configure_exit=127
```

```text
cmake --build runtime/build/windows --config RelWithDebInfo --target gta6rt dxgi_passthrough_test loader_test
bash: line 7: cmake: command not found
build_exit=127
```

```text
ctest --test-dir runtime/build/windows -C RelWithDebInfo -R "^(dxgi_passthrough|loader)$" --output-on-failure
bash: line 10: ctest: command not found
ctest_exit=127
```

`find runtime/build/windows -maxdepth 3 -type f` non ha prodotto artefatti. Nessun file di build e stato generato.

### C.2 Controlli statici disponibili

```text
g++ -std=c++20 -fsyntax-only -I runtime/shims /tmp/leonida_m12c4_shims_check.cpp
header_exit=0
```

Il controllo riguarda solo l'header `shims.h` e i costruttori `Entry` nominato/ordinale; non e una build Windows.

```text
g++ -std=c++20 -E -I runtime/shims runtime/shims/registry.cpp
runtime/shims/registry.cpp:1:10: fatal error: windows.h: No such file or directory
preprocess_exit=1
```

La preprocessing di `registry.cpp` e BLOCKED per assenza dell'SDK Windows. Non e un FAIL del codice.

I controlli Python:

```text
python3 -I tests/test_coverage_guard.py
....... Ran 7 tests in 0.001s  OK              exit 0
python3 -I tools/leonida-verify/verify_build.py --help
usage: verify_build.py ...                      exit 0
python3 -m py_compile tests/test_coverage_guard.py tools/leonida-verify/verify_build.py
exit 0
```

`git diff --check` ha restituito exit 0. `git diff --quiet` sulle aree protette ha restituito exit 0.

---

## D. Risultati della compilazione

| Elemento | Stato | Motivo |
|---|---|---|
| Runtime `gta6rt` x64 | BLOCKED | CMake, MSVC, Windows SDK assenti |
| `dxgi_passthrough_test` x64 | BLOCKED | toolchain Windows assente |
| `loader_test` x64 | BLOCKED | toolchain Windows assente |
| Linking e dipendenze Windows | BLOCKED | nessun linker Windows |
| Artefatti `.exe` / `.dll` | NOT RUN | configurazione fallita prima della generazione |
| Sintassi header `shims.h` | PASS statico | `g++`, non Windows, non linking |

Non viene dichiarata alcuna compilazione riuscita. Non e possibile verificare `/W4`, `/permissive-`, `/EHsc`, l'ABI
x64, il linking a `psapi` o il caricamento di `gta6rt_tls_host` senza l'ambiente Windows.

---

## E. Risultati dei test

| Test | Comando / target | Stato |
|---|---|---|
| Runtime build | `gta6rt` | BLOCKED |
| DXGI passthrough | `dxgi_passthrough_test` | BLOCKED |
| Loader | `loader_test` | BLOCKED |
| Registry name/ordinal | dentro `dxgi_passthrough_test`, `test_registry_identity` | BLOCKED |
| CTest DXGI/loader | `ctest -R "^(dxgi_passthrough\|loader)$"` | BLOCKED |
| Coverage guard Python | `python3 -I tests/test_coverage_guard.py` | PASS: 7 test |
| Verify build help | `python3 -I tools/leonida-verify/verify_build.py --help` | PASS: exit 0 |
| Python compile | `py_compile` | PASS: exit 0 |
| Whitespace/errori diff | `git diff --check` | PASS: exit 0 |
| Header `shims.h` | `g++ -fsyntax-only` | PASS statico, non MSVC |

**Nessun test C++/Windows e dichiarato PASS.** I test `dxgi_passthrough` e `loader` non hanno prodotto un eseguibile e
non sono stati tentati sotto Wine.

---

## F. Test BLOCKED e motivazioni

1. **Build runtime x64:** manca Windows x64, Visual Studio C++ Build Tools, MSVC e Windows SDK.
2. **Build `dxgi_passthrough_test`:** mancano MSVC, CMake e SDK; il target richiede anche `gta6rt_tls_host`.
3. **Build `loader_test`:** stesse dipendenze; il test genera PE e richiede il loader Windows.
4. **Esecuzione DXGI/registry:** non esiste l'eseguibile; non si puo verificare `GetProcAddress`, HMODULE host,
   forwarder, cache concorrente o `ERROR_PROC_NOT_FOUND`.
5. **Esecuzione loader:** non esiste l'eseguibile; non si puo verificare il caricamento ricorsivo o i fixture PE.
6. **Linking/dipendenze:** nessun linker Windows; non e verificabile l'import table finale.
7. **Wine:** assente; inoltre Wine non sostituisce una verifica MSVC nativa e non sarebbe stato dichiarato PASS come
   build Windows.

Comandi da eseguire sul PC Windows, senza modificarli in questa sede:

```powershell
cmake -S runtime -B runtime/build/windows -G "Visual Studio 17 2022" -A x64
cmake --build runtime/build/windows --config RelWithDebInfo --target gta6rt dxgi_passthrough_test loader_test
ctest --test-dir runtime/build/windows -C RelWithDebInfo -R "^(dxgi_passthrough|loader)$" --output-on-failure
```

---

## G. Analisi DXGI

### G.1 Nome e ordinale

`runtime/shims/shims.h` espone:

- `ExportOrdinal` e `ordinal(uint16_t)`;
- `Entry::by_ordinal` e `Entry::ordinal_value`;
- `find(dll, name)` solo nominale;
- `find_ordinal(dll, ordinal)` solo ordinale.

`runtime/shims/registry.cpp` usa `ExportKey` con `name`, `ordinal`, `by_ordinal`; la chiave e il tipo, non una stringa
`#n`. La tabella e `map<dll, map<ExportKey, void*>>`. `Table::Table` usa `ExportKey::numbered` per gli ordinali e
`ExportKey::named` per i nomi. Le lookup non convertono mai una forma nell'altra.

### G.2 Handle host e passthrough

`runtime/shims/library_loader.cpp`:

- su pseudo-handle: `IS_INTRESOURCE` sceglie `find_ordinal`, altrimenti `find`;
- su handle host: la stessa scelta, dopo aver ricavato il nome del modulo;
- `passthrough_proc` riceve l'HMODULE host gia disponibile;
- `passthrough_module` usa solo `GetModuleHandleA`, mai `LoadLibrary*`;
- un modulo assente restituisce `nullptr` e il chiamante imposta `ERROR_PROC_NOT_FOUND`;
- la cache usa `PassthroughKey` tipizzata;
- `t_in_passthrough` impedisce la ricorsione.

`grep` sul file conferma che le chiamate `LoadLibraryA/W/ExA/ExW` sono nei wrapper generali (`load_library_*`) e non
nel percorso `passthrough_module`/`passthrough_proc`. La stringa di commento "avoids a second LoadLibraryExA" descrive
la rimozione del caricamento, non una chiamata.

### G.3 Allowlist

La policy resta positiva e limitata a:

- `DXGIGetDebugInterface1`;
- `DXGIDeclareAdapterRemovalSupport`.

`CreateDXGIFactory`, `CreateDXGIFactory1` e `CreateDXGIFactory2` restano esclusi. Se non esiste una tabella DXGI,
`host_passthrough_export_allowed` conserva il comportamento precedente. La policy non e stata ampliata in M12C.4.

### G.4 Seam di test

`set_host_passthrough_test_dll` e la lettura in `host_passthrough_allowed` condividono
`g_passthrough_test_mutex`. Il seam e compilato solo con `LEONIDA_TEST_SEAMS`.

### G.5 Limite residuo

`runtime/src/pe_loader.cpp` usa ancora `LoadLibraryExA` per import host e forwarder host. Non e il passthrough DXGI;
il limite era gia documentato in M12C.3 e non e stato modificato in questa missione.

---

## H. Analisi registry

- `Table::Table` registra ogni voce con `insert_or_assign`; una voce duplicata mantiene l'ultima, coerentemente con il
  precedente `table()[key] = fn`.
- `find` cerca esclusivamente `ExportKey::named`; `find_ordinal` cerca esclusivamente `ExportKey::numbered`.
- `owns_dll` usa la presenza della mappa del modulo e l'allowlist dei moduli host; non usa piu un prefisso testuale.
- `host_passthrough_export_allowed` e positiva e dipende da `owns_dll("dxgi.dll")`.
- `make_unimplemented_thunk` conserva una chiave testuale `dll!name` per i thunk non implementati. Non e la registry e
  non restituisce un export; resta il residuo P3-6 gia documentato.
- Non sono state introdotte modifiche al codice della registry in M12C.4.

---

## I. Tracciabilita Git

`runtime/test/dxgi_passthrough_test.cpp`:

- esiste, 456 righe;
- non e ignorato da `.gitignore`;
- non e nell'indice (`git ls-files --error-unmatch` exit 1);
- e referenziato dal target CMake `dxgi_passthrough_test` (`runtime/CMakeLists.txt:341`);
- dipende da `src/pe_loader.cpp`, `shims/registry.cpp`, `shims/library_loader.cpp`, `gta6rt_tls_host`,
  `LEONIDA_TEST_SEAMS=1`, `GTA6RT_HOST_BASE`;
- contiene i test M12C/M12C.2 e i test P2-2/P2-3 aggiunti in M12C.3;
- non e stato compilato o eseguito in questa missione.

**Perche e untracked:** e un file nuovo creato durante il lavoro DXGI e nessuna missione ha potuto eseguire
`git add`/`git commit`. Non e un problema di ignore o di path.

**P2-5 non e chiuso.** La tracciabilita non puo essere dichiarata completata senza un commit e senza una verifica da
checkout pulito, entrambe vietate dalla missione. La lista sotto e pronta per il futuro commit, ma non e stata applicata.

---

## J. File previsti per il futuro commit

### Da includere nel commit DXGI/M12C.3

```text
runtime/shims/shims.h
runtime/shims/registry.cpp
runtime/shims/library_loader.cpp
runtime/src/pe_loader.cpp
runtime/test/dxgi_passthrough_test.cpp
```

### Modifiche preesistenti M12C, da valutare separatamente

```text
runtime/CMakeLists.txt
docs/d3d12_vulkan.md
docs/runtime_imports.md
```

### File validi ma estranei al perimetro DXGI

```text
tests/test_coverage_guard.py          (M07)
tools/leonida-verify/verify_build.py (M04)
```

Questi due file sono preesistenti e validi, ma non devono essere aggiunti automaticamente al commit DXGI. Vanno
tracciati con il lavoro a cui appartengono o con una decisione esplicita.

### Non modificati

Aree protette: backend Vulkan, D3D12, swapchain/PresentX, `dxgi_com.cpp`, `dxgi_swapchain.h`, factory DXGI future,
file del gioco. Nessuna implementazione M12D/M12E/M12F/M12G.

---

## K. Rischi residui

1. **Windows/MSVC non verificato:** compilazione, linking, ABI, warning level e runtime restano non provati.
2. **P2-5 aperto:** il test DXGI non e tracciato; un checkout pulito non puo costruire il target.
3. **P3-5 aperto:** nessun boundary `try/catch` verso `WINAPI`; un'eccezione di allocazione puo terminare il processo.
4. **P3-2/P3-3:** cache negativa assente e cache illimitata; il rischio e basso con la allowlist DXGI attuale.
5. **P3-8:** modulo host statico del test non liberato; e un limite del processo di test.
6. **P2-3 residuo:** `pe_loader`/forwarder host usano ancora `LoadLibraryExA`; non e il passthrough DXGI.
7. **Forwarder `#n`:** il formato PE resta ambiguo per un export letteralmente chiamato `#1`; i percorsi diretti sono
   tipizzati.

---

## L. Decisione finale

**COMPLETED WITH LIMITATIONS.**

La missione ha:

- verificato branch, HEAD, stato Git e assenza di modifiche protette;
- verificato l'ambiente e registrato l'indisponibilita Windows/MSVC;
- tentato i comandi di configurazione, build e CTest, ottenendo `command not found`;
- eseguito i controlli statici e Python disponibili;
- rianalizzato DXGI, registry, HMODULE host, ordinali, allowlist, forwarder e seam;
- preparato la lista Git senza eseguire staging o commit.

Non ha potuto:

- compilare o linkare il runtime e i test;
- eseguire `dxgi_passthrough_test`, `loader_test` o i test registry;
- chiudere P2-5 con un commit e un checkout pulito.

Prossime operazioni necessarie: eseguire i comandi Windows/MSVC su un host idoneo, raccogliere output e risultati,
verificare il checkout pulito, quindi creare il commit con i soli file elencati in §J. **M12D non e autorizzato.**

---

## SHA-256 del rapporto

Il valore seguente e lo SHA-256 dell'intero file con questa riga impostata a 64 zeri (normalizzazione riproducibile):

`b2dba05912282832cea14801891d87112e587f9f3d898ba06a7fbf882c2ce743`

L'hash completo del file finale e nel sidecar `reports/mission12c4-windows-msvc-verification.sha256`, creato dopo la
chiusura del testo.
