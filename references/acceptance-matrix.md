# Acceptance Matrix

A portable package is only accepted when each row has an observed result. Do not convert an assumption or a project self-test into a clean-machine claim.

| Area | Pass criterion | Suggested evidence |
|---|---|---|
| Complete payload | Node, pnpm, DSH CLI and Desktop exist; bootstrap is not required on the target | File inventory and target bootstrap exit code |
| Host independence | System Node, npm, dsh, PowerShell, Git, Bash, Python and .NET removed from test PATH; tools resolve inside the portable root | Process paths and `where`/Get-Command output |
| PowerShell | Kernel scripts run under bundled PowerShell 7; no host WindowsPowerShell path | `pwsh` version, script parser and launcher logs |
| Shell tools | Git and Bash execute; Bash inherits portable PATH | `git --version`, `bash -c` output |
| Python | Relocated venv Python runs; selected libraries import; pip cache is portable | `sys.executable`, import list, `pip --version` |
| .NET | Relocated SDK compiles and runs a console project without host SDK | `dotnet new`, `dotnet run`, `DOTNET_ROOT` |
| DSH payload | CLI reports the pinned version; Web returns a valid HTTP response; Desktop window opens | CLI output, final HTTP status and title, process/window evidence |
| Workspace | Default workspace is inside the portable root, not host Documents | workspace registry path and directory existence |
| Config isolation | Known DSH/cache/temp/tool paths resolve under the root; host `USERPROFILE` is not used as a portable data root | Environment assertions and a fresh-start test |
| Skills | Skill file counts/hashes match the intended set; DSH discovery compatibility is measured | Hash comparison and frontmatter discovery report |
| pnpm tree | Plugin dependencies resolve; relative shim executes; no broken link or build path remains | `pnpm list --depth 0`, shim `--help`, reparse scan |
| exFAT readiness | Zero reparse points or documented copy-only reconstruction; no build absolute paths in shims/state | Reparse count, path scan and a relocation test |
| Cleanup | No credentials, sessions, browser/IME profiles, `.bak` files or test logs | Upstream clean-ship and independent scan |
| Relocation | Chinese-and-space path and a different mapped drive both launch and preserve config | Validation logs from both paths |
| Long paths | Longest relative path is measured; destination root keeps full path within the target limit | Path-length report and short-root recommendation |
| Limitations | Clean second PC, real exFAT/FAT32 media, login/model/online plugin operations are either tested or explicitly listed as untested | Acceptance report and handoff notes |

## Manual negative tests

- Move the bundle to a different drive letter without reinstalling; confirm pnpm state and Python venv repair.
- Start Desktop after removing a pre-existing shell profile; confirm a fresh first-run state.
- Remove network access; confirm local toolchain and UI still start, while model calls fail with an understandable network error.
- Rename a skill's frontmatter name; confirm it is either skipped with a diagnostic or rejected by the documented rule.
- Disable the portable tool path; confirm the launcher fails visibly rather than silently using a host installation.
