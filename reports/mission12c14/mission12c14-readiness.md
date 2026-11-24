# LEONIDA 12C.14 - Readiness and maturity

## 1. Headline

| Measure | Value |
|---|---|
| Legacy technical maturity from 12C.13 | **65.35/100 (65%)** |
| 12C.14 increase | **0.00** |
| Native graphical gates passed | **0 of 7** |
| Windows 11 native validation | **NOT RUN / BLOCKED** |
| MSVC native build | **NOT RUN / BLOCKED** |
| D3D12 WARP on Windows | **NOT RUN** |
| D3D12 hardware | **NOT RUN / BLOCKED** |
| Vulkan hardware | **BLOCKED** |
| GPU shader pipeline | **NOT RUN** |
| Swapchain/presentation | **NOT RUN** |
| First launch readiness | **NOT READY FOR FIRST LAUNCH** |

The score was **not increased** for creating a probe, writing scripts, passing
CPU tests or packaging binaries. Those improve the ability to obtain evidence;
they are not native graphics evidence.

## 2. Category assessment

The weights below are a 12C.14 evidence rubric (100 points), separate from the
legacy 65.35 score. It prevents infrastructure work from being counted as
graphics compatibility.

| Category | Weight | Points | Status | Evidence / residual limit |
|---|---:|---:|---|---|
| Windows 11 native validation | 5 | 0.0 | NOT RUN | no Windows host |
| MSVC native build | 4 | 0.0 | NOT RUN | clang-cl cross build only |
| D3D12 WARP | 5 | 0.0 | NOT RUN | probe prepared; Wine WARP unavailable |
| D3D12 hardware | 8 | 0.0 | BLOCKED | no physical GPU/Windows |
| Vulkan loader | 3 | 1.2 | PARTIAL | Linux loader 1.4.309; Windows loader unverified |
| Vulkan hardware | 8 | 0.0 | BLOCKED | llvmpipe is CPU; no `/dev/dri` |
| Shader compilation | 6 | 3.0 | PARTIAL | CPU index/extraction tests; no DXC/FXC pipeline |
| Shader GPU pipeline | 8 | 0.0 | NOT RUN | no graphics device |
| Swapchain | 4 | 0.0 | NOT RUN | tests not built/run |
| Presentation | 4 | 0.0 | NOT RUN | no frame presented |
| Xbox/GDK ABI | 14 | 8.0 | PARTIAL | 106/81/63/39/74 synthetic checks under Wine; native NOT RUN |
| Xbox/GDK semantic compatibility | 10 | 4.0 | UNKNOWN/PARTIAL | stubs and not-served classes remain |
| Runtime integration | 8 | 4.0 | PARTIAL | CPU/shim integration only; no title |
| Stability | 8 | 7.0 | PARTIAL | 33 PASS cross-host; no native/GPU soak |
| Performance | 5 | 3.5 | PARTIAL | CPU import/lookup only; no GPU/FPS |
| **Total** | **100** | **30.7** | **EVIDENCE-LIMITED** | **not a GTA 6 readiness score** |

The 30.7 value is the new-evidence rubric, not a replacement for the legacy
65.35 project score. Reporting both prevents a false increase: the prior CPU/API
work remains, but this mission earned no native graphics points.

## 3. Gate-by-gate answers

| Question | Answer |
|---|---|
| Has LEONIDA demonstrated native Windows compilation? | **No** - cross-compiled only |
| Has it created a D3D12 hardware device? | **No** - not executed on Windows |
| Has it created a Vulkan hardware device? | **No** - llvmpipe is CPU |
| Has it executed a shader on GPU? | **No** |
| Has it presented a graphical frame? | **No** |
| Has it demonstrated Xbox/GDK ABI compatibility? | **Partial cross-host only** |
| Has it demonstrated Xbox/GDK semantic compatibility? | **No / UNKNOWN** |
| Has it demonstrated runtime integration? | **Partial CPU/shim only** |

## 4. What would move the score

Only evidence can move it:

1. native Windows environment and MSVC build;
2. tagged `D3D12_WARP_PASS` and `D3D12_HARDWARE_PASS` separately;
3. Vulkan physical and logical device on the RTX 4070 Ti;
4. a real shader compiled and executed on that device;
5. a swapchain created and a bounded number of frames presented;
6. native ABI tests plus documented semantic fixtures;
7. a separately authorized title integration, with no DRM bypass.

Until then the correct conclusion is **infrastructure advanced, native
compatibility not proven**, and the project is **NOT READY FOR FIRST LAUNCH**.
