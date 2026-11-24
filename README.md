▄▄▄▄▄▄ ▄▄▄▄▄▄ ▄▄▄▄▄▄ ▄▄▄▄▄▄▄▄▄▄▄▄▄ ▄▄▄▄▄▄▄▄▄▄▄▄▄      ▄▄▄▄▄▄▄▄▄▄▄▄▄ ▄▄▄▄▄▄ ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄ ▄▄▄▄▄▄ ▄▄▄▄▄▄     
██▄▄██ ██▄▄██ ██▄▄██ ██▄▄▄▄▄▄▄▄▄██ ██▄▄▄▄▄▄▄▄▄██      ██▄▄▄▄▄▄▄▄▄██ ██▄▄██ ██▄▄▄▄▄▄▄▄▄▄▄▄▄▄██ ██▄▄██ ██▄▄██     
██████ ██████ ██████ ████▀▀▀▀▀████ ████▀▀▀▀▀████      ████▀▀▀▀▀████ ██████ ███▀▀▀▀▀██▀▀▀▀▀███ ██████ ██████     
█████▓ ██████ ██████ █████▄▀██████ █████▄▀██████      █████▄▀██████ ██████ ████▄▀█████▄▀█████ ██████ ██████     
██▒▓█▒ ██▒▓██ ██▒▓██ ██▓███ ▀▄▄▄▄█ ██▓█ █ █▄▄▄▄▀      ██▓███ ▀▄▄▄▄█ ██▒▓██ █▄▄▄▀ ██▓█ █ █▄▄▄▀ ██▒▓██▄▀█▓▓██     
██░▒█░ ██░▒██ ██░▒██ ██░▒██        ██▒▓ ▀▄▄▄▄▄▄▄      ██░▒██        ██░▒██       ██▒▓ █       ██░▒▄▄▄▄▄████     
█▓█░▓█ █▓█░▓█ █▓█░▓█ █▓█░▓█        ██░▒▒▒▒▒▒▒▒ █      █▓█░▓█        █▓█░▓█       ██░▒▓█       ▀▀▀▀▀▀▀▄▓▒░▓█     
█▒▓█▒░ █▒▓█▒█ █▒▓█▒█ █▒▓█▒█ ▄▀▀▀▀█ █▓█░▓▄▀▀▀▀▀▀▀      █▒▓█▒█ ▄▀▀▀▀█ █▒▓█▒█       █▓█░▓█       ▄▀▀▀▀█ █░▒░▒█     
█░▒▓░▒ █░▒▓░█ █░▒▓░█ █░▒▓░█ █ ▓▓ █ █▒▓█▒█ ▄▀▀▀▀█      █░▒▓░█ █ ▓▓ █ █░▒▓░█       █▒▓█▒█       █░▒▓░█ █▓░▓░█     
▐▌░▒▒▌▄▐▒▒▒▐▌ █ ▒▒ █ █ ░▒ ▀▀▀ ▒▒ █ █ ░▒ ▀▀▀ ▒▒ █      █ ░▒ ▀▀▀ ▒▒ █ █ ▒▒ █       █ ░▒ █       █ ▒▒ █ █ ▒▒ █     
 ▓ ░░░░░░░ ▓  █ ░░ █ █ ░░░░░░░░░ █ █ ░░░░░░░░░ █      █ ░░░░░░░░░ █ █ ░░ █       █ ░░ █       █ ░░ ▀▀▀ ░░ █     
  ▀▄▄▄▄▄▄▄▀   █▄▄▄▄▀ █▄▄▄▄▄▄▄▄▄▄▄▀ █▄▄▄▄▄▄▄▄▄▄▄▀      █▄▄▄▄▄▄▄▄▄▄▄▀ █▄▄▄▄▀       █▄▄▄▄▀       █▄▄▄▄▄▄▄▄▄▄▄▀
Experimental Xbox-to-PC compatibility runtime

VICE CITY is an experimental software project focused on researching
and developing a PC runtime environment for Xbox game compatibility.

The project explores the components required to bridge console-oriented
software interfaces and a PC graphics environment. Development is
organized into engineering missions, with an emphasis on
reproducibility, diagnostics, and protecting original game data.

> [`<strong>`{=html}PROJECT STATUS:
> EXPERIMENTAL`</strong>`{=html}]{style=“color:#e53935”} — A complete,
> playable implementation has not been demonstrated. Compatibility and
> performance are not guaranteed.

────────

Project goals

• Research the requirements for running supported Xbox game components
in a PC environment.
• Develop a structured runtime and loader architecture.
• Investigate graphics-interface compatibility and translation paths.
• Improve diagnostics, logging, and reproducibility.
• Preserve original game files and avoid unnecessary modifications.

Technical areas

────────

Area                                Focus

────────

Runtime architecture                Core runtime components and
execution flow

Loader                              Module discovery, loading, and
symbol resolution

DXGI                                Graphics infrastructure
compatibility

Direct3D                            Graphics API behavior and interface
mapping

Vulkan                              Potential PC graphics backend and
translation layer

Shader pipeline                     Shader identification, indexing,
and conversion research

Registry and shims                  Typed exports, compatibility
mappings, and API shims

Diagnostics                         Structured logs, reports, and validation

Development principles

1. Evidence first: compatibility claims must be supported by tests,
logs, or reproducible analysis.
2. Incremental engineering: changes are divided into focused
missions with explicit outcomes.
3. Data integrity: original game files remain unchanged unless a
reviewed test requires otherwise.
4. Traceability: document design decisions, limitations, and known
failures.
5. No premature claims: passing an isolated test does not establish
full-game support.

Current development

Work has included investigation and implementation around loader
behavior, export resolution, DXGI-related safety, runtime shims, shader
indexing, and graphics-backend documentation.

Individual components may be implemented or tested independently. This
does not establish end-to-end game compatibility.

[<strong>{=html}IMPORTANT:</strong>{=html}]{style=“color:#e53935”}
The project remains incomplete until the full execution path has been
validated with repeatable results.

Roadmap

☐ Complete and validate core runtime components.
☐ Expand loader and module compatibility tests.
☐ Validate graphics-interface behavior.
☐ Improve shader pipeline coverage and diagnostics.
☐ Run controlled integration tests.
☐ Measure performance after functional correctness is established.
☐ Publish reproducible test results and remaining limitations.

Performance and compatibility

The long-term objective is to investigate whether a compatible PC
execution path can be achieved with acceptable performance.

No FPS figure, launch guarantee, or full-game compatibility claim is
made at this stage. Results depend on the implementation, game
workload, drivers, hardware, and completeness of the compatibility
layer.

Safety and file integrity

• Keep clean backups of source and test data.
• Prefer read-only inspection of original game files.
• Store generated files, logs, and test artifacts separately.
• Do not execute unknown binaries or scripts from untrusted sources.
• Record hashes when tracking files across test runs.

[<strong>{=html}VICE CITY does not claim affiliation with, endorsement
by, or ownership of any third-party platform or
publisher.</strong>{=html}]{style=“color:#e53935”} Trademarks and
game-related rights belong to their respective owners.

Disclaimer

VICE CITY is an independent experimental compatibility research project.
It is not an official product, emulator certification, or guarantee that
any particular game will run. Use only software and files you are
legally entitled to use.

────────

VICE CITY — Research. Runtime. Compatibility.