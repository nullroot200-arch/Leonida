# LEONIDA 12C.14 - Vulkan and physical GPU validation

## 1. Verdict

| Check | Status |
|---|---|
| Vulkan loader in this Linux VM | PASS (1.4.309) |
| Vulkan ICD discovery | PASS (several ICDs visible) |
| Vulkan physical hardware GPU | **BLOCKED** - none exposed |
| Vulkan logical device on hardware | **BLOCKED** |
| Vulkan queue and synchronization on hardware | **BLOCKED** |
| Windows `vulkan-1.dll` / Windows Vulkan SDK | **NOT VERIFIED** |
| Windows physical RTX 4070 Ti | **NOT VERIFIED** |
| Vulkan swapchain/presentation | **NOT RUN** |

The observed Vulkan device is **Mesa llvmpipe**, `PHYSICAL_DEVICE_TYPE_CPU`. It
must never be reported as `VULKAN_HARDWARE_PASS`.

## 2. Loader and ICD evidence

Collected on 2026-11-24T17:32:25Z with:

```text
/tmp/leonida-toolchain/test-bin/vulkaninfo --summary
```

Exit code: 0.

```text
Vulkan Instance Version: 1.4.309
apiVersion   = 1.4.305
deviceType   = PHYSICAL_DEVICE_TYPE_CPU
deviceName   = llvmpipe (LLVM 19.1.7, 256 bits)
driverID     = DRIVER_ID_MESA_LLVMPIPE
driverName   = llvmpipe
driverInfo   = Mesa 25.0.7-2+deb13u1 (LLVM 19.1.7)
```

ICD manifests visible under `/usr/share/vulkan/icd.d`:

```text
gfxstream_vk_icd.json
intel_hasvk_icd.json
intel_icd.json
lvp_icd.json
nouveau_icd.json
radeon_icd.json
virtio_icd.json
```

`ls -l /dev/dri` returned `No such file or directory`. No NVIDIA kernel driver or
`nvidia-smi` is available. An ICD manifest and a loader are not a device test.

## 3. What this does and does not prove

It proves that the Linux loader can enumerate a software Vulkan implementation.
It does not prove:

* that Windows has a Vulkan loader;
* that the NVIDIA driver exposes a Vulkan physical device;
* that a logical device, queue or fence can be created;
* that a shader can be compiled or executed;
* that a swapchain can be created or presented.

`VULKAN_HARDWARE_BLOCKED` is the correct gate result.

## 4. Cross-build limitation

The build used for the 12C.14 CPU suite has no Vulkan headers:

```text
Vulkan_INCLUDE_DIR = Vulkan_INCLUDE_DIR-NOTFOUND
Vulkan_LIBRARY     = Vulkan_LIBRARY-NOTFOUND
Vulkan_GLSLC_EXECUTABLE = Vulkan_GLSLC_EXECUTABLE-NOTFOUND
Vulkan_GLSLANG_VALIDATOR_EXECUTABLE = Vulkan_GLSLANG_VALIDATOR_EXECUTABLE-NOTFOUND
```

CMake therefore omitted the Vulkan-backed D3D12 device, Vulkan COM tests, GPU
test tools, `vk_pipeline_check`, `d3d12_state_map_test`, `gfx10_descriptors_test`
and the presentation tests that depend on them. The 33 PASS suite is CPU/shim
only.

## 5. Required Windows sequence

On the intended Windows 11 machine, after an authorized NVIDIA driver/Vulkan SDK
installation (no automatic install is performed here):

1. record Windows and driver versions;
2. run `vulkaninfo --summary` and save the complete output;
3. verify at least one physical device, not only the loader;
4. create a logical device and a queue on that physical device;
5. run a minimal queue/fence test;
6. only then consider shader compilation and pipeline evidence.

The repository's GPU harness, once built with Vulkan headers, can be invoked by
the native harness with `-RunGpuTests`; it now passes `--build` explicitly. A
`run_gpu_tests.py` pass must still be inspected for the actual device name and
must not be generalized to GTA 6 performance.

## 6. Missing evidence

No Windows Vulkan log, ICD name, physical-device UUID, driver version, queue
family, memory heap, pipeline or presentation result exists in this mission.
`VULKAN_DEVICE_FAIL` is not claimed because no Windows device attempt was made;
`VULKAN_HARDWARE_BLOCKED` is recorded.
