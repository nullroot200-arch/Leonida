# GPU pipeline corpus check

`runtime/test/vk_pipeline_check.cpp` creates a `VkShaderModule` for every entry in the translator's
`index.json` and, for compute shaders, a real compute pipeline with the runtime's descriptor and push
constant contract. It is a driver-level check: it proves the modules and pipelines are accepted by
the Vulkan implementation, not that the shader results are correct. Value-level checks are in
`docs/shader_validation.md`.

The checker exits nonzero if a module fails to load, a pipeline fails to compile, or the requested final
cache save fails. It still finishes checking the other entries and attempts the final save so the next run
can reuse successful pipelines. Before creating a Vulkan shader module, it checks that the file has a
complete SPIR-V header, the SPIR-V magic word, and a whole number of 32-bit words. A rejected input
module counts as a failure. A rejected partner stub is unavailable, so the affected pipeline is skipped.
It also exits 2, before loading Vulkan, if `index.json` is missing, unreadable, empty or malformed, so a wrong
directory can't pass as an empty corpus. A valid `{}` is an intentionally empty index.

For an index entry with `lds_bytes`, the checker compares the reported workgroup memory with the selected GPU's
`maxComputeSharedMemorySize` for compute or `maxMeshSharedMemorySize` for supported mesh shaders. An entry above its
limit counts as a module failure before Vulkan receives the shader. Older indexes without this field still use the
normal driver check. Mesh pipelines on devices without mesh shader support still use the existing feature skip.

## Check user-defined interfaces between stages

`tools/shader_link_check.py` compares the binary SPIR-V declarations of the shaders you plan to put in the
same pipeline. Use it before driver compilation to locate missing varyings, overlapping components, type
mismatches and per-primitive mesh declarations. It reads local modules and needs only Python.

```powershell
python -I tools/shader_link_check.py check --vs <vertex.spv> --ps <pixel.spv>
python -I tools/shader_link_check.py check --vs <vertex.spv> --gs <geometry.spv> --ps <pixel.spv>
python -I tools/shader_link_check.py check --ms <mesh.spv> --ps <pixel.spv>
python -I tools/shader_link_check.py inspect <shader.spv>
```

To audit a batch, give it the shader names from your local translation directory in a JSON file. A stage can
use a string or a `shader` and `entry` object. Names refer to `<name>.spv` in `--shader-dir`.

```json
{
  "version": 1,
  "pipelines": [
    {"name": "two-stage", "vs": "vs_example", "ps": "ps_example"},
    {"name": "with-geometry", "vs": "vs_example", "gs": "gs_example",
     "ps": {"shader": "ps_other", "entry": "main"}}
  ]
}
```

```powershell
python -I tools/shader_link_check.py batch pairs.json --shader-dir <spirv> --quiet --report link-report.json
```

The report records per-pipeline results. It uses the Vulkan Location and Component model, including one
outer array level for geometry inputs, mesh outputs and fragment `PerVertexKHR` inputs. Add `--maintenance4`
when the actual device enables that feature and the pipeline relies on matching a wider output vector to a
narrower input vector. See [Vulkan interface matching][interfaces].

Exit codes are `0` for compatible interfaces, `1` for a mismatch and `2` for a bad input or an interface
the reader cannot interpret. Continue with the driver checker for shader instruction validation, resource
bindings, device limits and pipeline state. Shader pairs must come from the caller. Share aggregate counts
and error classes, keeping the local shader files and reports that identify them on your PC.

[interfaces]: https://docs.vulkan.org/spec/latest/chapters/interfaces.html#interfaces-iointerfaces-matching

## Corpus

The translated corpus is 26,503 entries: 2,236 vertex, 12,101 pixel, 2,689 compute, 9,282 mesh and
195 geometry shaders. A run was split into 12 contiguous index shards of about 2,209 entries each.
The shards were run with a per-shard pipeline cache; each saves a cache of roughly 190-203 MB.

| Shard | Modules | CS pipelines | Result | Cache | Wall |
|---|---:|---:|---|---:|---:|
| s2 | 2,207 | 208 | pass | 196,869,933 B | 2h21m35s |
| s3 | 2,209 | 200 | pass | 190,022,273 B | 1h50m54s |
| s4 | 2,210 | 213 | pass | 198,941,511 B | 2h01m55s |
| s5 | 2,209 | 248 | pass | 201,997,254 B | 2h01m09s |
| s6 | 2,209 | 213 | pass | 190,939,966 B | 2h00m05s |
| s7 | 2,209 | 229 | pass | 202,013,032 B | 1h59m27s |
| s8 | 2,210 | 227 | pass | 199,121,775 B | 2h00m11s |
| s9 | 2,210 | 240 | pass | 198,407,685 B | 2h00m27s |
| s10 | 2,210 | 218 | pass | 202,890,354 B | 2h01m58s |
| s11 | 2,209 | 221 | pass | 200,378,101 B | 2h01m42s |
| **total (10/12)** | **22,092** | **2,217** | **0 module / 0 pipeline failures** | **1,981,581,884 B** | |

Stage split over the ten shards: 2,217 compute, 163 geometry, 7,767 mesh, 10,088 pixel and 1,857
vertex modules. The ten shards cover **22,092 of 26,503 entries (83.4%)** and **2,217 of 2,689
compute pipelines (82.4%)**.

Two shards did not complete:

- **s0** was stopped after 1 h 57 m at 81% of its bytes, with no read progress for 27 minutes on a
  3.61 MB compute shader.
- **s1** was stopped at the same time at 83% of its bytes on a 2.52 MB pixel shader.

They account for the missing 4,411 modules (472 compute, 32 geometry, 1,515 mesh, 2,013 pixel, 379
vertex) and 472 compute pipelines. No summary was printed for either shard. This is a driver
compile-time limit, not a module or pipeline rejection: no `MODULE FAIL` or `PIPELINE FAIL` line
exists in any completed shard.

A later full-corpus build on different hardware (RTX 4060 Ti, driver 595) completed **26,503 of 26,503**
modules and pipelines with **0 failures** and a 3.81 GB cache; see the "Full-corpus pipeline build" row in
[`docs/design.md`](design.md). The two stalled shards above therefore record a hardware/driver-specific
compile-time stall, not a project-wide limit.

The recurring slow family at every shard tail was a set of 6.7-7.2 MB ray-tracing resolve compute
shaders. One observed single-module stall exceeded 27 minutes. The tool has no per-shader timer, so
these are lower bounds, not exact compile times.

## Bounded guaranteed-finish sample

A separate bounded run covers eight 30-entry bins plus 12 large compute shaders: **252/252 modules
accepted** and **172/172 compute pipelines accepted**, 0 failures. Stage split: 172 compute, 20 each
geometry/mesh/pixel/vertex. Wave split: 97 wave64 / 75 wave32. The nine processes finished in about
5 minutes; their caches total 42,098,592 bytes. This is a sanity check on the same device, descriptor
layout and subgroup path, not a substitute for the 26,503-entry corpus.

A validation-layer run of the same 252 shaders (temporary instrumented copy, not committed) produced
**zero shader/module/pipeline messages**. The 9 errors and 36 warnings were loader noise from
overlay layers (a missing Epic JSON, three non-conforming layer names, one duplicate OBS hook). The
22,092 full-shard modules were not re-run through the validation layer; their result is driver
acceptance only.

## Limiting concurrent compilation of large modules

By default, a SPIR-V module larger than 4 MiB compiles alone. Smaller modules continue to use
`--jobs`. The gate covers module creation and both compute and graphics pipelines. The size
cutoff is a heuristic for [#884](https://github.com/ItsNotRexed/Leonida/issues/884), where several
compiles that each needed gigabytes of host RAM ran at the same time. The pipeline cache still
checkpoints during the run, and isolated modules count towards the regular results.

`--large-module-bytes N` changes the cutoff in bytes. Set it to `0` to disable isolation.

## Skipping huge modules

`vk_pipeline_check` now accepts `--max-bytes N`:

```powershell
vk_pipeline_check <spirv dir> [cache.bin] --max-bytes 2000000 --count 100
```

Every `.spv` larger than `N` is reported as `BIG SKIP <name> (<bytes>, limit <N>)`, counted by stage,
and excluded from the module/pipeline totals; the summary prints how many entries were checked. On a
30-entry smoke test with `--max-bytes 20000`, 24 modules were skipped and the remaining 6 pixel
modules passed.

The report above therefore states the limit and the skip count; a later run on an RTX 4060 Ti / 595
completed the full 26,503-entry set without them (`docs/design.md`). `--max-bytes` remains a visibility
tool, not a pass: a skipped module has not been validated.

## Crash isolation (`--isolate`)

A driver that dies while compiling one module (for example the RADV `SIGFPE` in
[#1721](https://github.com/ItsNotRexed/Leonida/issues/1721)) ends the whole process, so the rest of the corpus
used to need that module excluded by hand with `--start/--count`. With `--isolate` (POSIX only; on Windows it
prints an error and exits with 2) the tool runs the check in child processes instead:

```sh
vk_pipeline_check <spirv dir> cache.bin --isolate [--isolate-batch 256] [--jobs N ...]
```

- The parent opens no Vulkan device. It runs this executable, one child at a time, over `--isolate-batch`
  modules (default 256) of the same sorted, stage-filtered list, with the other options passed on (`--jobs` is
  the thread count inside each child). `--stats` is refused: children would overwrite one file.
- A child that is killed by a signal, or exits without finishing the pass after it started work, has its output
  discarded and its batch is bisected (re-run in halves) down to the module that kills it. That module is printed as
  `MODULE CRASH <name> (<stage>, driver crashed: SIGFPE)`, counted as a failed pipeline and listed at the end;
  the other modules are checked as usual and counted once. If both halves of a crashed batch run clean (a crash
  that needs several threads at once), the batch is reported as `MODULE CRASH [a, b) not reproduced ...` and
  counts as a failure. A child that fails before it starts work (no device, bad arguments) stops the run
  with exit status 1.
- The pipeline cache: children run one after another and each seeds from and saves to the same `cache.bin`,
  like the chunked runs above; the save is atomic, a crashed child saves nothing, so the file stays valid and
  holds everything the finished children compiled. The parent prints its size at the end.
- Exit status: 0 only if no module failed or crashed and the cache saved; 1 otherwise. The summary is
  aggregated by the parent (modules, pipelines, skips, `--cache-feedback`); the per-stage wave and compile-time lines
  of a normal run are not repeated. Output of a batch appears when its child finishes.
- Each child loads the cache again, so a very large cache makes small batches slow; raise `--isolate-batch`.
  There is no timeout: a hung compile still hangs.

Test hook, not for normal use: `VK_PIPELINE_CHECK_SIMULATE_CRASH=<module name substring>[:SIGNAL]` makes the
process raise `SIGNAL` (default `SIGFPE`; `SEGV`, `ABRT`, `KILL`, ... also accepted) just before the pipeline of a
matching module is created. `tests/test_vk_pipeline_check_isolate.py` uses it with five hand-assembled compute
shaders to check `--isolate` without a crashing driver; it skips when the tool isn't built or there is no
Vulkan device.

## Application pipeline-cache feedback

With `--cache-feedback`, the checker groups successful pipeline creations by translated shader stage
and reports three counts. A **hit** means the driver set both the valid-feedback bit and the
application-cache-hit bit. **No hit reported** means feedback was valid and the hit bit was clear.
**Unavailable** means the driver returned no valid feedback, or feedback was unsupported.
The three counts sum to the successful pipelines for the stage. Skips and failures are counted separately.

A driver can also use its own caches. A clear hit bit does not establish a fresh compile, and a
reported hit may reuse data populated earlier in the same process. The seed-file byte count alone
cannot identify which pipelines benefited.

To compare runs, start with a new cache path and keep the device, index and flags identical, including
`--stats` if used. For example, from a scratch directory that contains no `sample.cache`, run the same
command twice, replacing `path/to/spirv` with the local translated-shader directory.

```sh
vk_pipeline_check path/to/spirv sample.cache --cache-feedback
vk_pipeline_check path/to/spirv sample.cache --cache-feedback
```

On Windows with an RTX 5090 (driver 621.14), a synthetic three-compute, one-vertex and one-pixel
sample reported zero application-cache hits on its first run and five on the seeded run. On Mesa
llvmpipe the same five pipelines succeeded both times and neither run reported a hit.

## Wave64-emulated corpus (`--wave64-emulate`)

A GPU that only runs 32-wide subgroups (NVIDIA, Intel) needs the corpus translated with
`--wave64-emulate`. Its cross-lane operations go through workgroup memory instead of subgroup operations.
Its modules are larger, and they behave differently under the driver. All runs below are on an
RTX 4060 Ti (NVIDIA 595 driver, 32 GB RAM).

**Translation.** All 26,503 shaders translate and pass `spirv-val` at 43d4703. The run used eight
`--shard` processes and took 80 minutes. The modules total 13.68 GB: median 3.3% larger than the
previous emulated translation (spirv4), 90th percentile 16% larger, with exact-semantics rules added
in between.

**One process per chunk.** A single `vk_pipeline_check --jobs 4` run over the emulated corpus reached
21,000 of 26,503 pipelines with no failures. Then the driver's compiler ran out of memory
(`LLVM ERROR: out of memory`). With 2 jobs, one process later grew past 100 GB of committed memory.
Driver compiler memory isn't returned between pipelines, so the build now runs as one checker
process per 300–500 entries. Each process seeds from and saves to the same cache file, so the chunks
resume. Since #903 the checker also compiles modules over 4 MiB alone.

**The ScreenProbes shaders.** `indirect_diffuse_lighting`'s ScreenProbes_ActivateProbes,
ActivateProbesTarget and ActivateRays compute shaders were 60, 60 and 32 MB of SPIR-V. Their 3,281
typed-buffer loads each decoded every supported format inline. The exact UNORM/SNORM conversion added in
#755 made that about 900 instructions per load, which pushed the two largest past SPIR-V's id bound of
4,194,303 (#881). They were also the modules compiling when the driver ran out of memory. Since
dcd8ecf the run-time format decode is one function per module (`%fmt_decode_fn`):
ActivateProbes went from 6.16 M to 2.20 M instructions (41.7 MB), and all three now validate.

**Results.** With the pre-dcd8ecf translation (spirv4), entries 0–24,200 compiled with 0 module and
0 pipeline failures; two modules over 16 MiB were skipped in the chunked part. The spirv5 cache (all
26,503 entries, nothing skipped by size) is being built.

## Device

The reported runs used an NVIDIA GeForce RTX 5070 Ti (discrete, subgroup size 32 only), driver
621.24 / Windows 32.0.16.2124, Vulkan 1.4.357, loader 1.4.363, with 28 logical CPUs and 34 GB RAM.
The executable used the Vulkan SDK at `C:\VulkanSDK\1.4.363.0`; no source change was needed to build
or run it.

## What this does and does not prove

It proves, for the ten completed shards, that every translated module is accepted and every compute
pipeline is created with the runtime's resource contract. It does not prove:

- that any shader computes the right values (see `docs/shader_validation.md`);
- that the two incomplete shards are valid or invalid;
- that the graphics pipelines (vertex/pixel/geometry/mesh) execute or draw the right pixels: the tool
  creates them with `vkCreateGraphicsPipelines` (dynamic rendering) but never draws with them;
- that the game's descriptors, root signatures and push constants match the contract at run time
  (the missing executable still owns that).

No shader data, names or caches are committed. The caches live in the work directory and are inputs
to a later run, not part of the repository.
