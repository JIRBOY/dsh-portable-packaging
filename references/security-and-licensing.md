# Security and Licensing Notes

## Credentials and personal data

- DSH credentials, sessions, settings and browser data are user data. Do not include them in a distributable package.
- A portable bundle on a removable drive is readable by anyone who obtains the drive. Recommend an encrypted volume and a minimal account scope.
- Scan the whole source tree for API keys, bearer tokens, private keys, `.env` files and secret-like filenames before publishing or copying.
- Do not redirect `USERPROFILE` into the package unless every installed input method and system component has been tested. Prefer explicit DSH home/config/cache variables.
- Web mode may use the host default browser. Decide whether browser state belongs on the host or inside the package, and state the choice.

## Windows file-system behavior

- NTFS/ReFS can use ACL sandboxing. exFAT/FAT32/UNC cannot carry the same security descriptors; upstream portable kernels may switch to a compatibility mode with `danger-full-access`.
- Treat an exFAT U drive as a reduced-security environment. Do not classify it as a sandbox.
- pnpm can create directory symlinks. Copying with link-preserving tools or excluding links can produce a broken plugin tree. Materialize links or rebuild with a copy-only layout, then verify.
- Windows MAX_PATH may affect deeply nested dependencies. Measure the longest relative path and keep the root short.

## Toolchain and supply chain

- Prefer official sources with published SHA-256/SHA-512, Authenticode signatures or trusted release metadata.
- Record what was verified and what was not. A hash downloaded from the same unsigned source is not a signature.
- Do not execute a downloaded project before reviewing its bootstrap and install scripts.
- Keep build downloads, staging trees and test logs out of the release.
- Do not put live credentials into environment examples, logs, skill instructions or repository files.

## Licensing

- Original code/docs in this skill are MIT licensed.
- Node.js, PowerShell, Git for Windows, Python, .NET, DeepSeek Harness and their dependencies retain their own licenses.
- Do not redistribute a third-party application icon, binary or embedded resource unless its license permits it. The launcher icon helper is intended to run locally against a user-supplied application.
- This project is not affiliated with DeepSeek. Use the DeepSeek name only to describe interoperability.

## Safe default posture

1. Keep user data and credentials out of version control and release archives.
2. Use least privilege; avoid administrator installation.
3. Make network operations explicit: login, model calls, plugin installation and updates.
4. Preserve a recoverable build/rollback copy; never silently delete a working release.
5. Report unverified environments and compatibility gaps rather than describing them as passing.
