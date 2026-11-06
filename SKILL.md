---
name: dsh-portable-packaging
description: Build, harden, verify and package a self-contained Windows x64 DeepSeek Harness portable bundle, including full bootstrap, bundled PowerShell/Git Bash/Python/.NET, skill and workspace isolation, pnpm link materialization, a C# launcher and release cleanup. Use when creating or auditing a DSH drive that must run without host-installed Node.js or dsh.
---

# DSH Portable Packaging

## When to use

Use this skill when a DeepSeek Harness installation must run from a removable drive on Windows x64 without a host-installed Node.js, dsh, PowerShell, Git, Bash, Python or .NET SDK. It also applies when auditing an existing portable package for host dependencies, data leakage, broken links or credentials.

The target is Windows 10 22H2 or Windows 11 x64. The build machine needs network access and PowerShell; the target needs only the base Windows components.

## Core rules

1. Ship the complete runtime, not the upstream shell. A bare kernel still downloads Node.js, pnpm, DSH and Desktop on first run.
2. Reuse the upstream launchers, diagnostics, verification and rollback tools. Apply only minimal, documented patches.
3. Pin and verify every external artifact. Record the upstream tag or commit, URL, SHA-256/SHA-512 and the version actually installed.
4. Keep DSH home, agent home, workspace, caches and temporary files inside the portable root.
5. Do not redirect `USERPROFILE`. Windows input methods and other system components may write personal dictionaries into the package. Verify the host profile remains the host profile.
6. Materialize pnpm directory links or use a copy-only rebuild for exFAT. Make command shims relative to `%~dp0` or `$basedir`.
7. Remove credentials, sessions, browser profiles, backup files, build paths and test logs before release.
8. Report clean-machine, real exFAT, login and online-plugin tests as separate evidence, not assumptions.

## Workflow

### 1. Acquire and inspect

- Obtain a pinned upstream release tag or commit. Record its archive hash and whether the tag is signed.
- Extract into an empty staging directory. Read the bootstrap, environment, launcher, download and lifecycle scripts before execution.
- Keep source archives and downloads outside the final release.

### 2. Bootstrap official layers

Run the upstream bootstrap on a networked build machine. It must produce:

- `runtime/node/bin/node.exe`
- `runtime/pnpm/dist/pnpm.mjs`
- `app/node_modules/@deepseek-ai/dsh/lib/bin.js`
- `desktop/resources/app.asar`
- shared profile dependencies under `home/profiles/node_modules`

Prefer the app version paired with the kernel snapshot. Record the actual versions and checksums when a channel such as `latest` or `nightly` is used.

### 3. Add the portable toolchain

Use official Windows x64 artifacts with published checksums or Authenticode signatures:

- PowerShell 7, including a compatible `powershell.exe` entry when the kernel invokes that name.
- Git for Windows MinGit with Bash; expose `bash.exe` if the distribution only ships `sh.exe` and set `MSYS2_PATH_TYPE=inherit`.
- Python full/portable runtime and a relocatable venv. Repair `pyvenv.cfg`, activation scripts and absolute-path command launchers at launch.
- .NET SDK with `DOTNET_ROOT`, `DOTNET_CLI_HOME`, NuGet package and HTTP caches.
- Do not depend on host PATH ordering for any of these tools.

### 4. Construct the child environment

Set HOME and DSH/application data roots, `APPDATA`/`LOCALAPPDATA` where required, temporary directories, DSH home, agent home, workspace, package caches and tool-specific caches. Prepend all bundled runtime directories.

Keep `USERPROFILE` at the host value. Test with a local input method and confirm that personal dictionaries or statistics do not appear under the portable root.

### 5. Patch only necessary DSH behavior

- Bind the PowerShell executor to the bundled `pwshPath`. PATH alone is insufficient because DSH probes well-known host locations first.
- Set the workspace controller's `documentsDirectory` to a portable `workspace` root; otherwise the default workspace may be created under host Documents.
- Disable launch-time update checks when offline-friendly behavior is required; keep updates explicit.
- Patch optional components that hardcode host Windows PowerShell paths.
- Preserve upstream launchers, diagnostics, verify and rollback code.

### 6. Add skills and workspace

Copy only reviewed skills. Exclude VCS history, dependency trees, caches and credential-like files. Validate top-level `SKILL.md`, kebab-case names, YAML frontmatter and non-empty descriptions. Keep original incompatible skills unchanged and report them instead of silently renaming them.

### 7. Normalize links and shims

1. Enumerate reparse points.
2. Use `scripts/Materialize-ReparsePoints.ps1` to copy link targets into real directories, or rebuild with a copy-only layout.
3. Confirm zero reparse points before copying to exFAT/FAT32.
4. Rewrite pnpm `.bin` CMD, PS1 and POSIX sh shims with relative NODE_PATH.
5. Remove backup files and stale app pnpm metadata containing build paths.

Test `pnpm list --depth 0` and execute at least one relative shim.

### 8. Optional C# launcher

`assets/Launcher.cs` is a WinForms WinExe that resolves either the portable root or a project root containing `release/DSH-Portable`. It starts Desktop through a separate Shell process and polls for the window instead of waiting on a redirected stdout pipe. Web, preflight and validation open in a separate console.

Build with `scripts/Build-Launcher.ps1`; create an optional multi-size icon with `scripts/New-LauncherIcon.ps1`. The template targets Windows' built-in .NET Framework 4.8 and does not require an SDK on the target. Keep a `.cmd` fallback for systems where .NET Framework is disabled.

### 9. Clean and verify

- Remove test credentials, sessions, browser/IME profiles, shell profiles, crash output, `.bak` files and compile caches.
- Run `scripts/Test-PortableBundle.ps1 -Root <portable-root> -BuildPath <build-root>`.
- Run upstream `doctor`, `verify` and `clean-ship verify`.
- Run the isolated toolchain validation, then repeat from a Chinese/space path and a different drive letter.
- Record clean-machine, physical exFAT, login, model and online-plugin tests separately.

## Practical traps

- A bare shell is not an offline package.
- PATH ordering does not override DSH's well-known PowerShell locations.
- Redirecting `USERPROFILE` can copy host input-method data into the package.
- DSH default workspace may go to host Documents unless explicitly configured.
- `/XJ` or ordinary copies can skip pnpm directory links.
- Redirecting and waiting on a long-lived Desktop child can hang a launcher or make the child exit when the pipe closes.
- Clean-ship success does not replace checks for pnpm state, `.bin` shims, app metadata or browser/IME data.
- Deep paths can exceed the Windows 260-character limit; keep the portable root short.

## References

- `references/build-playbook.md`: detailed build sequence.
- `references/acceptance-matrix.md`: test matrix and evidence.
- `references/security-and-licensing.md`: credentials, exFAT and licensing.
- `references/versions-example.json`: public example versions; resolve current versions and hashes at build time.
- `scripts/Test-PortableBundle.ps1`: read-only release checks.
- `scripts/Materialize-ReparsePoints.ps1`: materialize link targets.
- `scripts/New-LauncherIcon.ps1`: local multi-size icon generation.
- `scripts/Build-Launcher.ps1`: compile the C# launcher template.

## Distribution boundary

Do not place official third-party binaries, application icons, credentials or a user's private skill library in this open-source repository unless the relevant license permits it. This repository contains the method and original tooling; each user builds the application payload locally.
