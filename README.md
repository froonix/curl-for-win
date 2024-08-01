<!--
Copyright (C) Viktor Szakats
SPDX-License-Identifier: CC-BY-SA-4.0
-->
[![Build status](https://ci.appveyor.com/api/projects/status/8yf6xjgq7u0cm013/branch/main?svg=true)](https://ci.appveyor.com/project/curlorg/curl-for-win/branch/main)
[![Daily status](https://github.com/curl/curl-for-win/actions/workflows/daily.yml/badge.svg)](https://github.com/curl/curl-for-win/actions/workflows/daily.yml)

# Reproducible curl binaries for Linux, macOS and Windows

- **We
  [plan](https://github.com/curl/curl-for-win/discussions/68) to stop
  building and distributing 32-bit Windows binaries on 2025-Aug-20.
  Custom 32-bit builds remain available with a deprecated,
  community-supported status. We recommend migrating to 64-bit Intel
  or ARM binaries.**
- [Download](https://curl.se/windows/) our
  `.tar.xz` or `.zip` packages,<br>PGP signed with:
  [`BDCF 067D 3908 B272 7A4A 9487 67C1 0037 40BF 8DC2`](https://raw.githubusercontent.com/curl/curl-for-win/main/sign-pkg-public.asc)
- Standalone `curl` tool and `libcurl` DLL. Static libraries included.
- Required: Windows Vista with
  [Universal CRT](https://support.microsoft.com/topic/update-for-universal-c-runtime-in-windows-322bf30f-4735-bb94-3949-49f5c49f4732)
  (x64, ARM64 or x86), macOS 10.9 Mavericks (Intel or ARM),
  any Linux (amd64, arm64 or experimental RISC-V) with
  [MUSL](https://en.wikipedia.org/wiki/Musl) builds.
- [HTTP/3](https://en.wikipedia.org/wiki/HTTP/3),
  [HTTP/2](https://en.wikipedia.org/wiki/HTTP/2) support,
  and [more](#features).
- ARM64 Windows builds are
  [Control Flow Guard](https://learn.microsoft.com/windows/win32/secbp/control-flow-guard)
  enabled. Intel builds have
  [CET](https://www.intel.com/content/www/us/en/developer/articles/technical/technical-look-control-flow-enforcement-technology.html)
  enabled. All builds have frame pointers enabled.
- Transparent builds, using open source code, run in
  [public](https://ci.appveyor.com/project/curlorg/curl-for-win/branch/main),
  with auditable [logs](#build-logs).
- [LLVM/Clang](https://clang.llvm.org/) build environment with
  [`mingw-w64`](https://sourceforge.net/p/mingw-w64/) via
  [Debian](https://packages.debian.org/testing/mingw-w64),
  [Homebrew](https://formulae.brew.sh/formula/mingw-w64),
  [MSYS2](https://www.msys2.org/).
  [`llvm-mingw`](https://github.com/mstorsjo/llvm-mingw) for ARM64.
- Windows cross-built and published via
  [AppVeyor CI](https://www.appveyor.com/). Linux built via GHA.
  Using reproducible OS image
  [`debian:testing-slim`](https://github.com/debuerreotype/docker-debian-artifacts/tree/dist-amd64/testing/slim)
  via [Docker](https://hub.docker.com/_/debian/). macOS built via GHA.
- Linux and macOS builds are experimental and *not* official curl builds.
- We verify components using SHA-256, and PGP where provided.
- We build [reproducible](https://reproducible-builds.org/) binaries,
  producing the same hash given the same input sources and C compiler.
- Patching policy: No local patches. We may apply patches if already merged
  upstream or &mdash; for showstoppers &mdash; had them submitted with fair
  confidence of getting merged.
- You can look up our package hashes in lines starting with `SHA` in the
  [build log](https://ci.appveyor.com/project/curlorg/curl-for-win/branch/main).
- Packages built across host platforms do not have identical hashes due to
  slightly different build options and toolchain builds/versions. Except
  `llvm-mingw` builds, which are reproducible across platforms. ARM64 and
  BoringSSL builds are such by default.
- We code-sign with a self-signed certificate on Windows, and avoid trusted
  timestamps for reproducibility.

# Features

Uses [LibreSSL](https://www.libressl.org/) TLS backend.

```
Windows:
Protocols: dict file ftp ftps gopher gophers http https imap imaps ipfs ipns ldap ldaps mqtt pop3 pop3s rtsp scp sftp smb smbs smtp smtps telnet tftp ws wss
Features: alt-svc AsynchDNS brotli CAcert HSTS HTTP2 HTTP3 HTTPS-proxy IDN IPv6 Kerberos Largefile libz NTLM PSL SPNEGO SSL SSPI threadsafe UnixSockets zstd

macOS:
Protocols: dict file ftp ftps gopher gophers http https imap imaps ipfs ipns ldap ldaps mqtt pop3 pop3s rtsp scp sftp smb smbs smtp smtps telnet tftp ws wss
Features: alt-svc AsynchDNS brotli CAcert HSTS HTTP2 HTTP3 HTTPS-proxy IDN IPv6          Largefile libz NTLM PSL        SSL      threadsafe UnixSockets zstd

Linux:
Protocols: dict file ftp ftps gopher gophers http https imap imaps ipfs ipns            mqtt pop3 pop3s rtsp scp sftp smb smbs smtp smtps telnet tftp ws wss
Features: alt-svc AsynchDNS brotli CAcert HSTS HTTP2 HTTP3 HTTPS-proxy     IPv6          Largefile libz NTLM PSL        SSL      threadsafe UnixSockets zstd
```
<details><summary>Alternate configurations:</summary><p>

```
"noh3", HTTP/2:
Protocols: dict file ftp ftps gopher gophers http https imap imaps ipfs ipns ldap ldaps mqtt pop3 pop3s rtsp scp sftp smb smbs smtp smtps telnet tftp ws wss
Features: alt-svc AsynchDNS brotli CAcert HSTS HTTP2       HTTPS-proxy IDN IPv6 Kerberos Largefile libz NTLM PSL SPNEGO SSL SSPI threadsafe UnixSockets zstd

"mini", without brotli and zstd, with OS TLS backend (Schannel, SecureTransport) if available:
Protocols: dict file ftp ftps gopher gophers http https imap imaps ipfs ipns ldap ldaps mqtt pop3 pop3s rtsp scp sftp smb smbs smtp smtps telnet tftp ws wss
Features: alt-svc AsynchDNS        CAcert HSTS HTTP2       HTTPS-proxy IDN IPv6 Kerberos Largefile libz NTLM PSL SPNEGO SSL SSPI threadsafe UnixSockets

"micro", without libssh2:
Protocols: dict file ftp ftps gopher gophers http https imap imaps ipfs ipns ldap ldaps mqtt pop3 pop3s rtsp          smb smbs smtp smtps telnet tftp ws wss
Features: alt-svc AsynchDNS        CAcert HSTS HTTP2       HTTPS-proxy IDN IPv6 Kerberos Largefile libz NTLM PSL SPNEGO SSL SSPI threadsafe UnixSockets

"nano", HTTP/1.1:
Protocols: dict file ftp ftps gopher gophers http https imap imaps ipfs ipns ldap ldaps mqtt pop3 pop3s rtsp          smb smbs smtp smtps telnet tftp ws wss
Features:         AsynchDNS        CAcert HSTS             HTTPS-proxy IDN IPv6 Kerberos Largefile libz NTLM PSL SPNEGO SSL SSPI threadsafe UnixSockets

"pico", HTTP/1.1-only:
Protocols:                                   http https            ipfs ipns
Features:         AsynchDNS        CAcert HSTS             HTTPS-proxy     IPv6          Largefile libz      PSL        SSL      threadsafe
```

"fnx", like "pico" but with full TLS and HTTP/2+ support:
Protocols:                                   http https            ipfs ipns
Features: alt-svc AsynchDNS        CAcert HSTS HTTP2 HTTP3 HTTPS-proxy     IPv6          Largefile libz      PSL        SSL      threadsafe
</p></details>

# Downloads

* Latest version for Windows:
  <br><https://curl.se/windows/>
* Specific versions for Windows, back to 8.2.0:<br>
  `https://curl.se/windows/dl-<curl-version>_<build-1-to-N>/`
  <br>Example:
  <br><https://curl.se/windows/dl-8.2.0_1/>

# Build logs

<https://ci.appveyor.com/project/curlorg/curl-for-win/history>

# Unstable/development daily builds

<https://github.com/curl/curl-for-win/actions/workflows/daily.yml>

# Guarantees and Liability

See [LICENSE](LICENSE.md).

Information in this document is subject to change without notice and does
not represent or imply any future commitment by the participants of the
project.

---
This document &copy; [Viktor Szakats](https://vsz.me/),
[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)
