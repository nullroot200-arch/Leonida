# Leonida — Szybki start (`pl-PL`)

> [!NOTE]
> Dokumentacja w języku angielskim ([`README.md`](../../../README.md), [`CONTRIBUTING.md`](../../../CONTRIBUTING.md) i
> [`docs/README.md`](../../README.md)) jest **wersją obowiązującą**. Ten przewodnik zawiera tylko stabilne instrukcje
> konfiguracji i budowania (zsynchronizowany z commitem `c0ac5fd6`). Aktualny stan projektu znajdziesz w
> [`README.md`](../../../README.md).

## Czym jest Leonida

Leonida to projekt statycznej rekompilacji Grand Theft Auto VI (Xbox Series), który uruchamia grę natywnie na
Windowsie. Port jest budowany **na Twoim komputerze z Twojej własnej kopii gry**. Shadery RDNA2 z konsoli są
tłumaczone na SPIR-V (Vulkan), zasoby gry są odczytywane bezpośrednio z Twojej paczki, a oprogramowanie systemowe
konsoli jest zaimplementowane od nowa w postaci tzw. shimów.

> [!IMPORTANT]
> To repozytorium **nie zawiera gry, kluczy ani pliku wykonywalnego** i nie wyjaśnia, jak je zdobyć. Nic tutaj nie
> odszyfrowuje danych ani nie obchodzi zabezpieczeń. Wszystko, co tworzy build (przetłumaczone shadery, wyodrębnione
> zasoby, folder roboczy i zapisy gry), pochodzi z Twojej kopii i **musi zostać wyłącznie na Twoim komputerze** —
> nigdy nie załączaj ani nie udostępniaj tych plików w issues ani pull requestach (zobacz
> [`CONTRIBUTING.md`](../../../CONTRIBUTING.md)).

Projekt jest na wczesnym etapie: **gra jeszcze się nie uruchamia**.

## Wymagania

- **Twoja własna kopia** paczki Xbox Series w wersji `1.0.2.1` (folder z plikiem `MicrosoftGame.Config` i archiwami `.rpf` czytelnymi na dysku jako zwykłe pliki).
- **Windows 10/11 x64** z około **350 GB wolnego miejsca** na pliki robocze (mogą trafić na inny dysk dzięki `--work`).
- [Python 3.12+](https://www.python.org/downloads/) (zaznacz *„Add python.exe to PATH”*).
- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0).
- [Vulkan SDK](https://vulkan.lunarg.com/) (`spirv-as`, `spirv-val` i `vulkaninfo`).
- [LLVM 21+](https://github.com/llvm/llvm-project/releases) z **targetem AMDGPU** (`llvm-mc`):
  - Oficjalna wersja LLVM dla Windowsa **nie** zawiera targetu AMDGPU.
  - Aby zbudować natywny `llvm-mc.exe` z AMDGPU, uruchom `.\scripts\build_llvm_mc.ps1` w PowerShellu w głównym
    folderze repozytorium. Skrypt wymaga `git` i narzędzi C++ z Visual Studio, ustawia zmienną `LLVM_MC` dla
    Twojego użytkownika i prosi o otwarcie nowego terminala, żeby zmienna była widoczna.
  - Jeśli używasz WSL, zainstaluj `llvm-21` w Ubuntu i ustaw zmienną w tej samej sesji PowerShella, w której
    uruchamiasz `make_game.py`:

    ```powershell
    $env:LLVM_MC = 'wsl -d Ubuntu -e /usr/lib/llvm-21/bin/llvm-mc'
    ```

    Więcej szczegółów w [`docs/design.md`](../../design.md#disassembling-shaders).
  - Na Linuksie wystarczy `llvm-mc` w `PATH`.
- **Visual Studio 2022** z pakietem *Programowanie aplikacji klasycznych w języku C++* i **Windows SDK `10.0.26100` lub nowszym** (potrzebne do etapu `runtime`, który używa root signatures w wersji 1.2).
- [ffmpeg](https://ffmpeg.org/download.html) w `PATH` *(opcjonalnie: dekoduje strumienie XMA2 i jest wymagany przy `--wav`)*.

## Jak zbudować

### Prosty sposób (Windows)

1. Zainstaluj powyższe wymagania.
2. Sklonuj repozytorium **razem z submodułem**:
   ```powershell
   git clone --recursive https://github.com/ItsNotRexed/Leonida
   ```
3. Kliknij dwukrotnie **`Build.bat`**.

Skrypt sam znajdzie Twoją kopię gry (Pobrane, Pulpit, Dokumenty, Games, folder użytkownika i główne foldery
wszystkich dysków, do dwóch poziomów w głąb). Rozpoznaje wersję po rozmiarach kilku plików, bez czytania dużych
danych. Jeśli znajdzie kilka kopii, zapyta, której użyć, a jeśli żadnej — poprosi o wklejenie ścieżki do folderu.
Przed startem sprawdza wymagania i wolne miejsce, a wynik zapisuje w `Documents\Leonida`. Przerwany build można
uruchomić ponownie — będzie kontynuowany od miejsca, w którym się zatrzymał.

### Z terminala (`make_game.py`)

```powershell
python -I make_game.py --find                          # lista kopii gry znalezionych na tym komputerze
python -I make_game.py --check                         # sprawdza Twoją kopię, niczego nie buduje
python -I make_game.py --game "D:\sciezka\do\paczki" --out "D:\Games\Leonida" --work "E:\leonida-work"
python -I make_game.py --stages shaders,assets         # tylko wybrane etapy
python -I make_game.py --game "D:\sciezka\do\paczki" --wav  # dodatkowo dekoduje Ogg Opus do PCM WAV (duże pliki)
python -I make_game.py --wave64-emulate auto           # auto (domyślnie), on lub off
```

Etapy wykonują się w tej kolejności: `check` → `shaders` → `assets` → `runtime` → `pipelines`.

- **`--wave64-emulate`**: emuluje shadery compute/mesh wave64 na kartach z podgrupami 32-wątkowymi (NVIDIA i Intel). Domyślny tryb `auto` pyta `vulkaninfo` i sam włącza emulację, gdy jest potrzebna.
- **`--work`**: najlepiej wskazać dysk z co najmniej 350 GB wolnego miejsca. Etap `shaders` trwa najdłużej i domyślnie używa połowy wątków procesora (można to zmienić przez `--jobs`).
- **Linux i Wine/Proton**: `make_game.py` działa też na Linuksie. Aby wykonać etap `runtime` poza Windowsem, podaj `--runtime-build <folder>` z buildem dla Windowsa (`gta6rt.exe` i `gta6rt_tls_host.dll`). Skrypt utworzy wtedy `gta6rt.sh`, który uruchamia program przez `wine` (albo przez Wine wskazane zmienną `WINE`, np. z Protona).

## Częste problemy

- **Pobrałeś repozytorium przyciskiem „Download ZIP” na GitHubie**: archiwum ZIP nie zawiera submodułu `third_party/rpf9-explorer`. Użyj `git clone --recursive` albo uruchom `git submodule update --init --recursive` w folderze repozytorium.
- **`llvm-mc` odrzuca `gfx1013` / AMDGPU**: najpewniej masz oficjalny instalator LLVM dla Windowsa. Użyj `scripts\build_llvm_mc.ps1` albo ustaw `LLVM_MC` na `llvm-mc` z WSL (`llvm-21`).
- **Błąd `D3D12_ROOT_SIGNATURE_DESC2` przy budowaniu runtime**: zaktualizuj Windows SDK do `10.0.26100` lub nowszego przez Visual Studio Installer albo `winget install Microsoft.WindowsSDK.10.0.26100`, usuń folder builda i skonfiguruj go ponownie.
- **Brak miejsca na dysku `C:`**: podaj `--work "D:\leonida-work"`, aby przenieść pliki robocze na inną partycję.

## Jak pomóc i uruchomić testy GPU

1. Przejrzyj otwarte PR-y i [issue koordynacyjne][coord], żeby nie dublować pracy. Zarezerwuj zadanie wpisem
   `claiming: <ID>` albo jednym zdaniem opisu, jeśli zadanie nie ma jeszcze ID.
2. Uruchom odpowiednie testy na syntetycznych danych wejściowych. Na przykład weryfikator manifestów testujesz
   poleceniem `python -I tests/test_manifest_verifier.py` w głównym folderze repozytorium.
3. W PR podaj ID zadania, opisz, co przetestowałeś, a jeśli uruchamiałeś testy GPU — podaj kartę i wersję
   sterownika. Zaznacz, czy korzystałeś z pomocy AI. Zasady znajdziesz w [`CONTRIBUTING.md`](../../../CONTRIBUTING.md).

[Przewodnik po testach GPU](../../testing.md) pokazuje, jak uruchomić testy bez plików gry.
Wyniki testów GPU publikuj w [issue #166](https://github.com/ItsNotRexed/Leonida/issues/166).

[coord]: https://github.com/ItsNotRexed/Leonida/issues?q=is%3Aissue%20is%3Aopen%20in%3Atitle%20%22Coordinating%20who%20works%20on%20what%22
