# Shader containers embedded in the package's DLLs

**Status: measured** on the 1.0.2.1 package. This note covers the shader programs that ship outside
`shaders.rpf`: the DXBC containers inside the package's DLLs, what each one carries, and what the measurement
changes for the ray-tracing and upscaling paths. No container, shader or payload is reproduced here; the tables
hold counts, offsets, chunk names and module identifiers.

## 1. Why they matter

`make_game.py`'s `shaders` stage carves `shaders.rpf` only (`make_game.py`:655). Two DLLs in the same package
carry compute programs of their own:

* `XboxBvhBuilder.dll`, Microsoft's XDXR acceleration-structure builder. Its constructor creates compute PSOs
  through device slot 62, and the builder is on the critical path for ray tracing.
* `amd_fidelityfx_upscaler_xbox.dll`, the FidelityFX 4.1.1 upscaler. Its programs are the `ACCC`/`FSPX` format
  covered in [fspx.md](fspx.md); this note only counts them.

`tools/pe_shader_containers.py` scans a binary for DXBC containers, validates the chunk table, reads the `ILDN`
module name and reports what each container carries. `--extract` writes the containers and an `index.json` the
translator reads; extracted shaders are game data and must stay in the user's work folder.

```sh
python -I tools/pe_shader_containers.py <dll> --json <work>/containers.json --extract <work>/embedded/dxbc
```

## 2. Inventory

The 16 DLLs and the package's root files were scanned. All the containers are in two DLLs:

| image | containers | bytes | min / median / max | chunks |
|---|---:|---:|---:|---|
| `XboxBvhBuilder.dll` | 52 | 674,404 | 4,072 / 7,454 / 74,508 | `SFI0 ISG1 OSG1 PSV0 RTS0 STAT ILDN HASH DXIL` |
| `amd_fidelityfx_upscaler_xbox.dll` | 29 | 289,656 | 1,764 / 5,176 / 42,616 | `SFI0 ISG1 OSG1 PSV0 RTS0 HASH ACCC` |
| other 14 DLLs | 0 | 0 | — | — |

The 29 `ACCC` containers hold `FSPX` payloads ([fspx.md](fspx.md)); the 52 `DXIL` containers are the subject of
this note. The FSR DLL has one rejected `DXBC` hit: the bytes are an immediate in its own magic check, and the
validator rejects it (the scan reports both counts).

**Every one of the 52 containers carries two representations of its program:**

* an LLVM bitcode blob in the `DXIL` chunk (`BC C0 DE`, 1,820 to 70,276 bytes), and
* an `XDAT` directory with tag `0x0d` whose payload starts with `XBCH`: the console program. The same chunk also
  holds tag `0x07` (a second `DXIL` program header) and tag `0x12` (a 16-byte hash). The `STAT` chunk holds a
  second, different bitcode blob, not the same one.

### `STAT` and the `0x07` program header

Measured over all 52 builder containers in one local 1.0.2.1 package; no shader data is included here. The
bitcode spans below use the `DxilProgramHeader`/`DxilBitcodeHeader` offsets and sizes defined by
[DirectXShaderCompiler](https://github.com/microsoft/DirectXShaderCompiler/blob/main/include/dxc/DxilContainer/DxilContainer.h).
All spans fit inside their enclosing parts, and all 104 `STAT` and outer `DXIL` bitcode modules were accepted by
`llvm-dis` 21.1.8. The header's size-in-dwords equals its enclosing part or record length in every case.

* **`STAT`:** 52/52 contain a `DXIL` program header and a bitcode module distinct from the outer `DXIL` bitcode.
  All have `dx.entryPoints` and `dx.resources` metadata, and none defines a function in the `llvm-dis` output;
  the outer modules define functions. DirectXShaderCompiler calls this the shader-statistics part and uses a valid
  `STAT` module for reflection (see its
  [container reflection implementation](https://github.com/microsoft/DirectXShaderCompiler/blob/main/lib/HLSL/DxilContainerReflection.cpp)).
  The metadata-only shape is consistent with that role; the builder's actual consumption of `STAT` is not measured.
* **XDAT tag `0x07`:** 52/52 contain a `DXIL` program header whose declared bitcode is byte-identical to that of
  the outer `DXIL` part. None contains the `NOBC` marker. The whole `0x07` record is not the same as the whole
  outer part, which also contains `XDAT`. This differs from the `NOBC` form documented for the game's shader
  corpus in [fssm_crosscheck.md](fssm_crosscheck.md); it does not change that separate measurement.

The bitcode is what a PC D3D12 compiler consumes; the runtime path is the `XBCH` record. The constructor passes
the **whole container** to the compute-PSO call: at `0x180021330` it loads `DAT_180025700` with size `0x1134`
(4,404 bytes, the size of container 0, `CopyAndCompactBVH`) and calls `FUN_18000c470`, whose vtable call at
`+0x1f0` (slot 62) receives that pointer, its size and two zero words. `FUN_18001d400` adds two more PSOs,
`XDXR PostBuildInfoQuery` (0x14a4 bytes) and `XDXR GetBVHCompactedSize`. `bvh_builder_test` measures **53** PSO
creations during construction over the **52** containers ([d3d12_vulkan.md](d3d12_vulkan.md) A.2), so one
container is created twice. It is **`GetBVHCompactedSize`** (5,284 bytes = 0x14a4): creations **#47 and #53** pass
byte-identical containers (RT-182, `LEONIDA_BVH_RECORD62=1`, which now prints each creation's module from its `ILDN`
part and says when a container repeats). 0x14a4 is also the size this section gives for `XDXR PostBuildInfoQuery`,
which fits `FUN_18001d400`'s two XDXR PSOs being this one container created twice, once under each name; the test
does not see the PSO names, so that last step is a hypothesis. The creation order, by module (it is not the table
order of section 3; `CopyAndCompactBVH` is #52, not the first):

| creations | modules, in the order of the `CreateComputePipelineState` calls |
|---|---|
| #1-#13 | `InitPartitionedHeaders`, `PT_WriteOfflinePartition`, `PT_WritePartitions`, `PT_WriteInstances`, `PT_LoadInstances`, `PT_BeginPass`, `ResetCounterValues`, `InitHeaders`, `CopyForBVHUpdate`, `ResetToIndexBuffer`, `CopyCounters`, `CalculateMortonCodes`, `CalculateMortonCodes64` |
| #14-#29 | `BitonicPreSortCS`, `BitonicOuterSortCS`, `BitonicInnerSortCS`, `BitonicPreSort64CS`, `BitonicOuterSort64CS`, `BitonicInnerSort64CS`, `RadixReset`, `RadixCount`, `PrefixSum64`, `PrefixSum128`, `PrefixSum256`, `PrefixSum512`, `PrefixSum1024`, `PrefixSum2048`, `PrefixSum4096`, `RadixAlloc` |
| #30-#46 | `RearrangeTriangles`, `RearrangeBVHs`, `LoadInstances`, `SplitInstances`, `LoadTriangles`, `LoadProceduralGeometry`, `ReloadTriangles`, `ReloadProcedurals`, `PT_ConstructBVH4`, `ConstructBVH4`, `RefitBVH4`, `BuildBVHSplits`, `BuildBVHSplits64`, `FindTreelets`, `ResetKDOP`, `BuildKDOP`, `BuildApexPointMap` |
| #47-#53 | `GetBVHCompactedSize`, `DecompressHeader`, `LeafRehydration`, `Box16Rehydration`, `Box32Rehydration`, `CopyAndCompactBVH`, `GetBVHCompactedSize` (again) |

## 3. The 52 modules

The `ILDN` PDB path gives one module per container, all under
`X:\americas\src\dev\rage\3rdparty\Microsoft\XboxBvhBuilder\Build\Release\Output\XboxBvhBuilder\` (Microsoft's
component integrated into RAGE, not Rockstar shader code). Grouped by phase:

| phase | modules |
|---|---|
| sort (11) | `BitonicPreSortCS`, `BitonicPreSort64CS`, `BitonicInnerSortCS`, `BitonicInnerSort64CS`, `BitonicOuterSortCS`, `BitonicOuterSort64CS`, `RadixCount`, `RadixAlloc`, `RadixReset`, `CalculateMortonCodes`, `CalculateMortonCodes64` |
| prefix (7) | `PrefixSum64`, `PrefixSum128`, `PrefixSum256`, `PrefixSum512`, `PrefixSum1024`, `PrefixSum2048`, `PrefixSum4096` |
| kdop (3) | `BuildKDOP`, `ResetKDOP`, `BuildApexPointMap` |
| build (7) | `ConstructBVH4`, `BuildBVHSplits`, `BuildBVHSplits64`, `SplitInstances`, `FindTreelets`, `RearrangeBVHs`, `RearrangeTriangles` |
| refit (2) | `RefitBVH4`, `CopyForBVHUpdate` |
| load (6) | `LoadTriangles`, `ReloadTriangles`, `LoadInstances`, `LoadProceduralGeometry`, `ReloadProcedurals`, `ResetToIndexBuffer` |
| path tracing (6) | `PT_ConstructBVH4`, `PT_BeginPass`, `PT_LoadInstances`, `PT_WriteInstances`, `PT_WritePartitions`, `PT_WriteOfflinePartition` |
| rehydration (3) | `Box16Rehydration`, `Box32Rehydration`, `LeafRehydration` |
| headers/util (7) | `DecompressHeader`, `InitHeaders`, `InitPartitionedHeaders`, `GetBVHCompactedSize`, `CopyCounters`, `ResetCounterValues`, `CopyAndCompactBVH` |

## 4. They are console FSSM, and the existing translator already takes them

The `XBCH` record has the same shape as the game's own shaders: `XBCH` + stored/unpacked sizes + a zlib stream
that expands to `FSSM` ([fssm_crosscheck.md](fssm_crosscheck.md)). On all 52 containers:

| step | result |
|---|---|
| `tools/fssm_unpack.py` | **52/52** decompress to a valid `FSSM` blob (716 B to 101,320 B, median 2,200 B) |
| `tools/shader_disasm.py --mcpu gfx1013` | **52/52** disassemble; 42 with no invalid word, 10 with invalid words in the code |
| `tools/rdna2spirv.py` | **51** translate and pass `spirv-val` (`main` `49475796`) |

When this page was first written, 42 translated and 10 stopped at four rules. Three of those rules have landed since
(`427c1376`, from #1968), and one program still waits on a fifth rule:

| module(s) | blocker then | now |
|---|---|---|
| `BuildKDOP`, `LoadInstances`, `ReloadProcedurals`, `LoadProceduralGeometry`, `LoadTriangles` | `global_atomic_fmax` | translate |
| `PT_LoadInstances` | `global_atomic_fmin` | translates |
| `Box32Rehydration`, `ReloadTriangles` | `buffer_load_ushort` | translate |
| `LeafRehydration` | `tbuffer_load_format_x GFX10_FORMAT_8_UINT` | translates |
| `Box16Rehydration` | `buffer_load_ushort` | stops at `buffer_store_short` (#1864, open) |

The disassembly count is unchanged: the same 42 programs have no invalid word, and 10 have invalid words in the
code. All 10 of those translate; `Box16Rehydration` is one of the 42 clean ones.

On current `main`, 51 of the 52 programs translate and pass `spirv-val`. The four earlier blockers were
implemented in #1871 and #1968 (`427c1376`):

* `tbuffer_load_format_x GFX10_FORMAT_8_UINT` (#1871) unblocked `LeafRehydration`.
* `global_atomic_fmax` (#1968) unblocked `BuildKDOP`, `LoadInstances`, `ReloadProcedurals`, `LoadProceduralGeometry`, and `LoadTriangles`.
* `global_atomic_fmin` (#1968) unblocked `PT_LoadInstances`.
* `buffer_load_ushort` (#1968) unblocked `Box32Rehydration`, `ReloadTriangles`, and the load half of `Box16Rehydration`.

The single remaining untranslated program stops at one rule:

| module(s) | blocker |
|---|---|
| `Box16Rehydration` | `buffer_store_short` (#1864) |

| module(s) | blocker then | now |
|---|---|---|
| `BuildKDOP`, `LoadInstances`, `ReloadProcedurals`, `LoadProceduralGeometry`, `LoadTriangles` | `global_atomic_fmax` | translate |
| `PT_LoadInstances` | `global_atomic_fmin` | translates |
| `Box32Rehydration`, `ReloadTriangles` | `buffer_load_ushort` | translate |
| `LeafRehydration` | `tbuffer_load_format_x GFX10_FORMAT_8_UINT` | translates |
| `Box16Rehydration` | `buffer_load_ushort` | stops at `buffer_store_short` (#1864) |

The disassembly count is unchanged: the same 42 programs have no invalid word, and 10 have invalid words in the
code. All 10 of those translate; `Box16Rehydration` is one of the 42 clean ones.

Reproduction, after `--extract` above:

```sh
python -I tools/fssm_unpack.py <work>/embedded/dxbc
python -I tools/shader_disasm.py <work>/embedded/dxbc/fssm --out <work>/embedded/dxbc/disasm --mcpu gfx1013
python -I tools/rdna2spirv.py <work>/embedded/dxbc/disasm --out <work>/embedded/spirv
```

## 5. What this changes

* **The RT builder does not need a DXIL path for the console code.** Its programs are RDNA2 `FSSM`, and 51 of
  52 already pass `spirv-val` with the translator the project uses for the game's 26,503 shaders. The bitcode in
  the same container is a second representation (the one the PC-compiler experiment measured); it is not what
  the console runtime executes.
* **The missing rules were small, and only one is left.** `global_atomic_fmax`/`fmin` (6 programs),
  `buffer_load_ushort` (3) and `tbuffer_load_format_x` with format 8 (1) were ordinary translator rules, not a new
  compiler backend, and they are on `main`. The one left is `buffer_store_short` (#1864), for `Box16Rehydration`.
* **The rehydration programs are the ones closest to the shipped data.** `Box16Rehydration`,
  `Box32Rehydration` and `LeafRehydration` are exactly the programs that would turn the dehydrated BVH packs
  into runtime trees ([bvh.md](bvh.md) §3.1). `LeafRehydration` translates since #1871, `Box32Rehydration`
  translates since #1968 (`427c1376`), and only `Box16Rehydration` awaits #1864 (`buffer_store_short`).
* **What is still open.** None of the 52 has been executed on a GPU; translation and `spirv-val` do not prove the
  output. Which of them the game actually creates is a call-site question (RT-5). The module-to-pipeline order
  above comes from `ILDN`, not from a runtime trace. The `STAT` metadata-only shape is consistent with reflection,
  but whether the builder consumes it has not been measured.

## 6. Tool and tests

`tools/pe_shader_containers.py` is standard library only and reads the file, never runs it. It accepts a
container only when the chunk table is sorted, 4-byte aligned, entirely inside the declared total and its last
chunk ends exactly at that total; that is what rejects the FSR DLL's `DXBC` immediate. The synthetic tests in
`tests/test_pe_shader_containers.py` build containers by hand (no game data) and cover the accepted layout, a
bare magic, a truncated chunk, an `ACCC`/`FSPX` container, the `ILDN` name and the extraction index.
