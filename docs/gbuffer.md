# Deferred G-buffer targets and declared output signatures (`PROC-146`)

Reported by @Silliana in [#1891](https://github.com/ItsNotRexed/Leonida/issues/1891) for `PS_DeferredTextured` and
checked here across all **2,989 `*Deferred*` pixel shaders** (and all **1,703 six-target pixel shaders**) in the
1.0.2.1 `shaders.rpf` corpus. Counts, target masks, numeric constants and format requirements only; no shader text or
disassembly.

## 1. Corpus census of deferred pixel-shader output signatures (`OSG1` / `PSV0`)

Every DXBC container in `shaders.rpf` carries an `OSG1` (and `PSV0`) output signature table with `{register,
semantic_index, component_type, mask, min_precision}` per `SV_TargetN` output, and the unpacked FSSM header records the
exported target count as `u32` at `+0x0FC`.

Across the **2,989** pixel shaders with `Deferred` in their container name (including **807** `PS_DeferredTextured`
variants: 380 five-target, 371 six-target and 56 three-target):

| Targets declared (`+0x0FC` / `OSG1`) | `*Deferred*` PS count | `PS_DeferredTextured` count | Corpus-wide PS count | `OSG1` component type on all colour targets | Per-target `OSG1` write masks (`SV_Target0..N-1`) |
|---:|---:|---:|---:|---|---|
| 6 (`SV_Target0..5`) | 953 | 371 | 955 | `float32` (`ctype = 3`, `prec = 0`) | `0xF, 0xF, 0xF, 0xF, 0x3, 0xF` (`mrt4` is 2-component `RG`) |
| 6 (`SV_Target0..5`) | 737 | 0 | 747 | `float32` (`ctype = 3`, `prec = 0`) | `0xF, 0xF, 0xF, 0xF, 0xF, 0xF` (all six `RGBA`) |
| 5 (`SV_Target0..4`) | 1,160 | 380 | 1,168 | `float32` (`ctype = 3`, `prec = 0`) | `0xF, 0xF, 0xF, 0xF, 0x3` (`mrt4` is 2-component `RG`) |
| 5 (`SV_Target0..4`) | 2 | 0 | 20 | `float32` (`ctype = 3`, `prec = 0`) | `0xF, 0xF, 0xF, 0xF, 0xF` |
| 3 (`SV_Target0..2`) | 125 | 56 | 248 | `float32` (`ctype = 3`, `prec = 0`) | `0xF, 0xF, 0x3` (`mrt2` is 2-component `RG`) |
| other (`0, 1, 2, 4` or `5 + SV_Depth`) | 12 | 0 | — | `float32` (3 single-target `uint32`) | depth-only, discard, or reduced passes |

In the compiled RDNA2 code of every 5-target and 6-target `PS_DeferredTextured` variant, all exported targets
(`mrt0..mrt4` or `mrt0..mrt5`) pack their outgoing register pairs with `v_cvt_pkrtz_f16_f32` and export them with
`exp mrtN, ... compr` (`EXP_FORMAT_FP16_ABGR`).

## 2. G-buffer target layout (`mrt0..mrt5`)

Confirming #1891 against the 5-target (`mrt0..mrt4`) and 6-target (`mrt0..mrt5`) `PS_DeferredTextured` programs:

| Target | `OSG1` mask | Expected RTV format class | Channel layout and encoding in `PS_DeferredTextured` |
|---|---|---|---|
| `mrt0` (`SV_Target0`) | `0xF` (`RGBA`) | `R8G8B8A8_UNORM` | **Albedo + alpha/material byte:** `rgb` holds base colour/albedo; in 6-target variants `a` packs a byte extracted from an integer register and scaled by `1.0 / 255.0` (`0x3b808081`). |
| `mrt1` (`SV_Target1`) | `0xF` (`RGBA`) | `R8G8B8A8_UNORM` | **Scalar in `r` + 24-bit octahedral world normal split across `g`, `b`, `a`:** see section 3 below. |
| `mrt2` (`SV_Target2`) | `0xF` (`RGBA`) | `R8G8B8A8_UNORM` | **Square-root encoded material/specular channels:** `rgb` values pass through hardware square root (`sqrt(x)`, or `sqrt(1.0 - sqrt(x))` on 6-target variants) before export so the deferred lighting pass squares them back; `a` holds an unencoded `[0, 1]` scalar (`0.5` or a conditional select). |
| `mrt3` (`SV_Target3`) | `0xF` (`RGBA`) | `R8G8B8A8_UNORM` | **Flags + byte IDs:** `x` and `y` carry clamped `[0, 1]` material/shading flags biased by a dither term (`scale = 2.0 / 255.0` = `0x3c008081`, `offset = -1.0 / 255.0` = `0xbb808081`); `z` and `w` carry two 8-bit integer IDs extracted with byte-to-float conversion (`ubyte0`, `ubyte1`) and multiplied by `1.0 / 255.0` (`0x3b808081`). |
| `mrt4` (`SV_Target4`) | `0x3` (`RG`, 2,113 deferred PS) or `0xF` (`RGBA`, 739 deferred PS) | Float format (e.g. `R16G16_FLOAT`) | **Motion vectors:** unscaled signed float screen-space motion offset (`xy`, with `zw` disabled as `off, off` on the 2,113 `mask = 0x3` variants). |
| `mrt5` (`SV_Target5`) | `0xF` (`RGBA`, 1,690 deferred PS) | `R8G8B8A8_UNORM` | **Sixth deferred target** on the 6-target permutations (`rgb` material terms + clamped alpha). |

## 3. The 24-bit octahedral normal in `mrt1.gba` and why binding `f16` targets breaks lighting

`PS_DeferredTextured` does not store a 3-channel `(nx, ny, nz)` normal in `mrt1`. Instead:

1. The unit world normal `(nx, ny, nz)` is divided by its $L_1$ norm $|nx| + |ny| + |nz|$ and octahedral-folded across
   the $nz \le 0$ hemisphere into $(u, v) \in [-1, 1]^2$.
2. Both coordinates are quantized to 12-bit unsigned integers $q_u, q_v \in [0, 4095]$ with the scale constant
   `2047.5` (`0x44fff000`):
   $$q_u = \operatorname{uint32}(u \cdot 2047.5 + 2047.5), \qquad q_v = \operatorname{uint32}(v \cdot 2047.5 + 2047.5)$$
3. The two 12-bit integers are combined into one 24-bit word $q = (q_v \ll 12) \mid q_u$ (`q_u` in bits `[11:0]`,
   `q_v` in bits `[23:12]`).
4. The three bytes of $q$ (`ubyte0 = q[7:0]`, `ubyte1 = q[15:8]`, `ubyte2 = q[23:16]`) are converted to `f32`,
   multiplied by `1.0 / 255.0` (`0x3b808081`), rounded toward zero to `f16` (`v_cvt_pkrtz_f16_f32`), and exported to
   `mrt1.g`, `mrt1.b`, and `mrt1.a`.

### Consequence for the runtime and test harnesses

- **Declared signatures do not separate `UNORM8` from `FLOAT16`:** because `OSG1` and `PSV0` declare `float32` on all
  six `SV_Target0..5` outputs and the RDNA2 code uses `exp mrtN ... compr` (`EXP_FORMAT_FP16_ABGR`) for all of them,
  neither the DXBC signature nor the FSSM export opcode indicates that `mrt0..mrt3` (and `mrt5`) are `R8G8B8A8_UNORM`
  while `mrt4` is a float motion target.
- **Why binding `R16G16B16A16_FLOAT` to `mrt1` or `mrt3` corrupts the packed bytes:** `v_cvt_pkrtz_f16_f32` rounds
  `byte * (1.0 / 255.0)` **toward zero** (`RTZ`), producing an `f16` value slightly *below* `byte / 255.0` for most byte
  values `1..254`. When `mrt1` is bound as `R8G8B8A8_UNORM`, the render-target output stage quantizes with
  $\lfloor x \cdot 255.0 + 0.5 \rfloor$ and restores the exact byte `0..255`. When `mrt1` is bound as an `f16` float
  target and the lighting pass reconstructs the bytes by multiplying by `255.0`, the RTZ truncation drops 1 LSB on
  `ubyte1` (bits `[15:8]`, which straddles the 12-bit split between $q_u$ and $q_v$) and `ubyte2` (bits `[23:16]`),
  shifting the reconstructed normal by whole octahedral steps and producing speckled lighting (#1891).
- The runtime must always bind the PSO's declared `RTVFormats[]` (`R8G8B8A8_UNORM` for the byte-packed G-buffer targets
  and a float format for `mrt4`) and must never infer `R16G16B16A16_FLOAT` for all G-buffer attachments from `OSG1` or
  `exp ... compr`.
