# LEONIDA 12C.14 - Shader pipeline

## 1. Verdict

| Layer | Status | Evidence |
|---|---|---|
| Shader identity/index model | PASS (CPU/synthetic) | `shader_library` CTest PASS |
| FSSM extraction and SHA-256 | PASS (CPU/synthetic) | FIPS vectors, synthetic DXBC containers |
| FSPX program extraction | PASS (CPU/synthetic) | synthetic kind-0/kind-6 payloads |
| Hash lookup, duplicates, malformed JSON | PASS (CPU/synthetic) | `shader_library` checks |
| Fixture path selection | PASS (CPU/synthetic) | `shader_fixture_path` PASS |
| SPIR-V f16 conversion | PASS (CPU/synthetic) | `spirv_f16_halves` PASS |
| Shader corpus | SKIP | `LEONIDA_SHADERS` not supplied |
| Shader compilation with DXC/FXC | **NOT RUN** | no Windows shader compiler in this session |
| GPU pipeline creation | **NOT RUN** | no graphics device |
| GPU shader execution | **NOT RUN** | no graphics device |
| Shader/game compatibility | **NOT CLAIMED** | no game content |

`SHADER_CPU_TESTS_PASS` is the strongest label supported here. It is not
`SHADER_GPU_PASS` and not evidence about GTA 6's shaders.

## 2. Architecture preserved

The existing runtime index is keyed by:

* `(stage, fssm_sha256)` for FSSM programs;
* `(stage, fspx_code_sha256)` for FSPX programs;
* `fspx_state_sha256` as the additional state discriminator when a kind-0 entry
  exists.

The carve name is only used to locate the `.spv` path; it is not the content
identity. These decisions were not changed in 12C.14.

Relevant implementation: `runtime/src/shader_library.h`.
Relevant documentation: `docs/fspx.md`, `docs/api_compatibility.md` and the
shader-library test comments.

## 3. Tests actually executed

From the safe CTest suite on 2026-11-24:

| Test | Result | What it covers |
|---|---|---|
| `shader_fixture_path` | PASS | packaged/local/missing fixture path selection and directory rejection |
| `shader_library` | PASS | SHA-256 vectors, zlib stored/fixed/dynamic inflate, JSON reader, FSSM extraction, FSPX extraction, index lookup, duplicate candidates, malformed index refusal |
| `spirv_f16_halves` | PASS | SPIR-V f16 half conversion |
| `shader_library_corpus` | SKIP | needs `LEONIDA_SHADERS` naming a translated work folder |

The full suite was:

```text
ctest --test-dir /tmp/leonida-toolchain/build-12c10 \
  -E '^(run_|gta6rt_rejects_)' --output-on-failure
```

Result: 33 PASS, 7 SKIP, 1 DISABLED, 0 FAIL; exit 0; 170.34 s.

`shader_library` includes synthetic checks for:

1. stage-specific lookup;
2. SHA-256 of the content bytes;
3. cache/index hit and miss behavior via `find`/`candidates`;
4. two entries with the same program and different metadata;
5. an FSSM key not matching an FSPX key;
6. malformed JSON refusing the whole index;
7. malformed/truncated DXBC and FSSM payloads;
8. wrong stated sizes and truncated FSPX directories;
9. no-stage and no-hash entries;
10. missing `.spv` modules.

These are parser/index tests. They do not create a GPU pipeline.

## 4. What `device_proxy` would have added

`device_proxy` is the test that compiles a trivial `cs_5_0` shader through
`d3dcompiler_47.dll` and creates a compute pipeline state. It was **SKIPPED**
because Wine exposes no WARP adapter. Therefore even the trivial shader compile
path was not executed in 12C.14. Do not cite that test as a shader PASS.

## 5. Missing GPU evidence

No D3D12 or Vulkan pipeline was created. No HLSL, DXIL or SPIR-V shader was
executed. No shader was validated against a real driver. No game shader was
used for synthetic tests.

The next valid evidence is a Windows GPU run that records:

* adapter and driver;
* shader stage and bytecode hash;
* compiler/tool version;
* pipeline creation HRESULT;
* command submission and fence completion;
* validation-layer output, if enabled.

A successful CPU extraction or hash comparison is necessary but not sufficient
for GPU compatibility.
