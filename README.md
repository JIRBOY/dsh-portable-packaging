# DSH Portable Packaging Skill

An open-source method and toolkit for building a Windows x64 DeepSeek Harness portable bundle that runs without host-installed Node.js or dsh.

This repository contains only original documentation, scripts and a C# launcher template. It does not contain DeepSeek binaries, the DeepSeek logo, user skills, credentials, build logs or local absolute paths.

## What it covers

- Full offline bootstrap of the official DSH app and Desktop from the portable kernel.
- Bundled PowerShell 7, Git/GNU Bash, Python virtual environment and .NET SDK.
- Portable home, skill root, cache, temporary files and default workspace.
- pnpm link materialization for exFAT/U drives.
- Relative pnpm command shims.
- Optional C# WinForms launcher with a custom icon workflow.
- Verification, cleanup and security checklists.

## Requirements

- Windows 10 22H2 or Windows 11 x64 for the resulting bundle.
- A networked build machine with PowerShell 5.1 or later.
- About 5 GB free during build; the finished bundle is roughly 4 GB plus user data.
- Use a short destination root such as `E:\DSH-Portable`.

The launcher template targets the .NET Framework 4.8 included with Windows 10 22H2 and Windows 11. DSH itself uses its bundled Node runtime. A `.cmd` fallback should remain available for systems where .NET Framework is disabled.

## Quick start

1. Read `SKILL.md` and `references/build-playbook.md`.
2. Obtain a pinned upstream portable-kernel release and inspect it before execution.
3. Bootstrap the full Node/pnpm/DSH/Desktop layers on the build machine.
4. Apply the portable environment and workspace configuration described in the playbook.
5. Materialize pnpm links:

   ```powershell
   pwsh -File scripts/Materialize-ReparsePoints.ps1 `
     -Source <built-tree> -Destination <release-tree> `
     -RelativeRoots home/profiles
   ```

6. Verify the release:

   ```powershell
   pwsh -File scripts/Test-PortableBundle.ps1 `
     -Root <release-tree> -BuildPath <build-tree>
   ```

7. Optionally build the C# launcher:

   ```powershell
   pwsh -File scripts/New-LauncherIcon.ps1 `
     -ApplicationExe <desktop-exe> -OutputIco <launcher.ico>
   pwsh -File scripts/Build-Launcher.ps1 `
     -OutputDirectory <release-root> -IconFile <launcher.ico>
   ```

8. Run upstream `doctor`, `verify` and `clean-ship verify`; then test Web, Desktop, Python, .NET, Bash and a relocated copy.

## Repository layout

```text
SKILL.md
README.md
LICENSE
references/
  build-playbook.md
  acceptance-matrix.md
  security-and-licensing.md
  versions-example.json
scripts/
  Test-PortableBundle.ps1
  Materialize-ReparsePoints.ps1
  New-LauncherIcon.ps1
  Build-Launcher.ps1
assets/
  Launcher.cs
```

## Verification limits

Passing these checks on a build machine does not prove:

- behavior on a second clean Windows installation;
- behavior on a real exFAT/FAT32 U drive;
- login, model calls or online plugin installation;
- absence of every possible Windows/Electron/browser cache write.

Record these as explicit remaining tests rather than claiming them.

## License and trademarks

Original code and documentation are MIT licensed. DeepSeek Harness, Node.js, PowerShell, Git for Windows, Python and .NET remain under their respective upstream licenses. This project is not affiliated with DeepSeek. Do not redistribute an official application icon or binary unless its license permits it; `New-LauncherIcon.ps1` is a local build helper, not a bundled asset.
