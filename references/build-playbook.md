# Build Playbook

This playbook describes a proven sequence for creating a Windows x64 DeepSeek Harness portable bundle. Use placeholders such as `<portable-root>` and `<build-root>`; never publish a bundle containing your own absolute paths or personal data.

## 1. Freeze the inputs

1. Choose a published kernel tag. Record the tag, commit SHA, archive URL and archive SHA-256.
2. Pin the Node.js and pnpm versions required by the kernel and the DSH package engines.
3. Pin PowerShell, MinGit, Python, .NET and the Desktop installer version. Keep a manifest of URL, version and checksum.
4. Verify official checksums or Authenticode signatures before extracting or executing anything.

Use official upstream sources only. A GitHub tag that is unsigned should be recorded as unsigned rather than described as signed.

## 2. Stage the kernel

- Extract into a new empty staging directory.
- Inspect `preflight.cmd`, `env.cmd`, the PowerShell bootstrap, launcher scripts, download tool and install lifecycle code before running them.
- Keep source archives and downloads outside the final release tree.
- Run the kernel in a separate build copy, never directly in the final destination.

## 3. Bootstrap the official layers

Run the upstream bootstrap on the networked build machine. It must produce:

- `runtime/node/bin/node.exe`
- `runtime/pnpm/dist/pnpm.mjs`
- `app/node_modules/@deepseek-ai/dsh/lib/bin.js`
- `desktop/resources/app.asar`
- shared profile dependencies under `home/profiles/node_modules`

Pin the app version to the kernel's matching snapshot where possible. Desktop may use an official update manifest; record the actual version and SHA-512 after installation.

A target machine must be able to start with all four layers present without executing bootstrap or downloading a package.

## 4. Add the portable toolchain

Prefer official ZIPs with published hashes.

- PowerShell 7: bundle `pwsh.exe`; provide a compatible `powershell.exe` copy if the kernel invokes it by that name. Patch the kernel's hardcoded host-PowerShell check and filesystem detection.
- Git for Windows MinGit: provide Git and Bash. If MinGit only names `sh.exe`, test and expose a `bash.exe` equivalent; set `MSYS2_PATH_TYPE=inherit`.
- Python: use an official full/portable runtime and a relocatable venv. Repair `pyvenv.cfg` and activation scripts at launch; replace absolute-path entry-point launchers with relative `.cmd` wrappers or wrapper commands.
- .NET SDK: set `DOTNET_ROOT`, `DOTNET_CLI_HOME`, NuGet package and HTTP caches. Do not require a host SDK or Visual Studio.
- Never rely on host PATH ordering for any of these tools.

## 5. Design the child environment

Set the following in a batch environment file and assert them at build time:

- `HOME` and DSH/application-specific data roots.
- `APPDATA`, `LOCALAPPDATA`, `TMP` and `TEMP` when the portable behavior requires them.
- `DSH_HOME`, `DSH_AGENTS_HOME`, package caches, staging and temporary paths.
- Tool-specific roots and caches: Python, pip, .NET, NuGet, PowerShell.
- Path entries for the bundled Node, pnpm, PowerShell, Git/Bash, Python and .NET.

Do **not** override `USERPROFILE`. Windows input methods and other system components may use it to write personal dictionaries or statistics; if it points into the portable drive, the release can accidentally contain host personal data. Verify `USERPROFILE` remains the host value and test with an installed IME.

Prefer explicit DSH/home variables over broad Windows profile redirection. A browser launched by Web mode may create its own profile; decide whether that profile should live on the host or inside the package and document the choice.

## 6. Patch only the necessary DSH behavior

- Bind the PowerShell executor to the bundled executable with a profile `pwshPath` value. PATH alone is insufficient because DSH checks well-known Program Files locations first.
- Set `workspace-controller.documentsDirectory` to a portable `workspace` root. Without this, DSH creates its default workspace under the host Documents folder.
- Disable automatic update checks at launch when the package is intended to be offline-friendly; keep update commands explicit.
- Patch any hardcoded host PowerShell path in optional components to prefer the portable PowerShell.
- Leave upstream `start-web.cmd`, `start-desktop.cmd`, `dsh.cmd`, diagnostics and rollback mechanisms intact unless a specific failure requires otherwise.

## 7. Add skills and workspace

- Copy only reviewed skill files. Exclude `.git`, dependency trees, caches and credential-like files.
- Scan for actual tokens, private keys and `.env` secrets; do not copy them.
- Validate DSH discovery rules: top-level `<name>/SKILL.md`, lowercase kebab-case `name`, valid frontmatter and a non-empty `description`.
- Keep originals unchanged when source skills are incompatible; report the skipped list instead of silently renaming user skills.
- Put the default workspace root inside the package and test a fresh start with no existing `home/storages` state.

## 8. Normalize links and shims for exFAT

1. Enumerate reparse points in the complete tree.
2. Use `scripts/Materialize-ReparsePoints.ps1` to copy link targets into real directories, or rebuild the tree with a copy import method that does not produce links.
3. Confirm the final release has zero reparse points before copying to exFAT/FAT32.
4. Rewrite pnpm `.bin` CMD, PS1 and POSIX sh shims so NODE_PATH is based on `%~dp0`, `$basedir` or `$PSScriptRoot`, not a build absolute path.
5. Remove `.bak` files and stale app pnpm metadata that point at a build path.

Run the released plugin tree through `pnpm list --depth 0` and execute at least one relative shim such as `js-yaml --help`.

## 9. Optional C# launcher

The template in `assets/Launcher.cs` is a WinForms WinExe that:

- resolves either the portable root or a project root containing `release/DSH-Portable`;
- starts Desktop through a hidden Shell process and observes the window/process rather than waiting on a redirected stdout pipe;
- opens Web, preflight and validation in a separate console;
- can be compiled against Windows' built-in .NET Framework 4.8.

Build steps:

1. Create a multi-size icon from the local application icon with `scripts/New-LauncherIcon.ps1`.
2. Read the launcher template before compiling.
3. Compile with `scripts/Build-Launcher.ps1` and verify the GUI, custom icon and actual Desktop startup.
4. Keep a `.cmd` fallback under a non-primary tools directory for systems with .NET Framework disabled.
5. Do not commit the extracted official icon or compiled application binary to the open-source skill repository.

## 10. Clean and release

- Remove or move test credentials, sessions, browser profiles, shell profiles, crash logs, `.bak` files and generated compile caches.
- Keep only the NuGet/pip/pnpm configuration and caches that are intentionally portable.
- Run `scripts/Test-PortableBundle.ps1` with `-BuildPath` pointing to the build tree.
- Run upstream `doctor`, `verify` and `clean-ship verify`.
- Copy to a Chinese/space path and a different mapped drive; run isolated validation again.
- Record what was not tested: a second clean PC, a physical exFAT drive, login, model calls and online plugin installation.
