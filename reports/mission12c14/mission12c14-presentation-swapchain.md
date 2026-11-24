# LEONIDA 12C.14 - Presentation, swapchain and graphical output

## 1. Verdict

| Check | Status |
|---|---|
| Test window created | **NOT RUN** |
| D3D12 swapchain created | **NOT RUN** |
| Vulkan swapchain created | **NOT RUN** |
| Backbuffer format/size/count checked | **NOT RUN** |
| Frame synchronization checked | **NOT RUN** |
| Controlled present executed | **NOT RUN** |
| Resize path exercised | **NOT RUN** |
| Clean shutdown exercised | **NOT RUN** |
| GPU output verified | **NOT RUN** |

No graphical frame was presented. No FPS measurement exists.

## 2. Existing code versus built artifacts

The repository contains presentation-oriented sources and tests, including:

* `runtime/test/d3d12_present_test.cpp` - a Vulkan-backed device behind the
  Xbox-ABI proxy, 60 cleared frames, resize and readback;
* `runtime/test/xbox_present_test.cpp` - `PresentX` and frame events;
* `runtime/test/dxgi_swapchain_test.cpp` - Vulkan-backed IDXGIFactory4 /
  IDXGISwapChain3 over a Win32 HWND;
* `runtime/test/vk_presenter_sync_test.cpp` - Vulkan presenter synchronization;
* shims in `runtime/shims/xbox_present.*` and `runtime/shims/d3d12_vulkan_device.*`.

A filesystem check for the corresponding executables in the 12C.14 build
returned **no files**:

```text
find /tmp/leonida-toolchain/build-12c10 -maxdepth 2 \
  \( -iname 'd3d12_present_test.exe' -o -iname 'xbox_present_test.exe' \
     -o -iname 'dxgi_swapchain_test.exe' -o -iname 'vk_presenter_sync_test.exe' \)
# no output
```

The CMake configuration had no Vulkan headers (`Vulkan_INCLUDE_DIR-NOTFOUND`),
so these targets were not built. Source presence is not execution evidence.

## 3. Important labeling distinction

`d3d12_present_test` is named for the D3D12/Xbox-facing API, but its backing
device in this repository is Vulkan (`gta6rt_d3d12_com` and the Vulkan device
shim). Even if it later passes on Windows, it would be a **Vulkan-backed
presentation** result, not a native D3D12 hardware swapchain result. It must not
be used to claim D3D12 hardware PASS.

Similarly, a visible window or a cleared color is not proof of GTA 6 rendering.

## 4. Missing native sequence

The Windows handoff must first build the relevant targets with a Vulkan SDK and
an actual GPU. Then, separately:

1. create a test window;
2. create the backend device and swapchain;
3. verify format, buffer count and extent;
4. render a controlled clear;
5. submit and wait on a fence;
6. present a bounded number of frames;
7. resize and recreate the swapchain;
8. close cleanly;
9. record every HRESULT/VkResult and validation message.

No such log exists in 12C.14. The correct status remains **NOT RUN**.

## 5. Performance caution

Even a successful 60-frame synthetic presentation would not establish GTA 6
FPS, frame pacing, shader compatibility or memory behavior. No FPS value is
reported in this mission.
