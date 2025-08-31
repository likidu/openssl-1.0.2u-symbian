# Backport: TLS 1.1/1.2 support for Qt 4.7.4 with OpenSSL 1.0.2u

## Overview

- Adds TLS 1.1 and 1.2 to Qt 4.7.4’s SSL stack when used with OpenSSL 1.0.2u.
- Keeps API/ABI stable; apps opt-in via QSsl::SslProtocol or use AnyProtocol.
- Uses runtime symbol resolution; works with dynamically loaded 1.0.2u DLLs.

## What Changed

- New protocols: QSsl::TlsV1_1 and QSsl::TlsV1_2 in `src/network/ssl/qssl.h`.
- Resolver: Declares and resolves `TLSv1_1_*_method` and `TLSv1_2_*_method` in
  `src/network/ssl/qsslsocket_openssl_symbols_p.h/.cpp`.
- Enforcement: For TLSv1.1/1.2 selections, creates an SSLv23 context and sets
  `SSL_OP_NO_*` flags to disable lower versions in
  `src/network/ssl/qsslsocket_openssl.cpp`.
- Cipher parsing: Maps “TLSv1.1” and “TLSv1.2” description strings to the new
  protocol enums in `src/network/ssl/qsslsocket_openssl.cpp`.

## Files Modified

- `src/network/ssl/qssl.h:75`: Added enum values: `TlsV1_1`, `TlsV1_2`.
- `src/network/ssl/qsslsocket_openssl_symbols_p.h`:
  - Added TLSv1.1/1.2 method prototypes for client/server on both const and non-const branches.
  - Defined `SSL_OP_NO_TLSv1_1` and `SSL_OP_NO_TLSv1_2` if missing.
- `src/network/ssl/qsslsocket_openssl_symbols.cpp`:
  - Added `DEFINEFUNC` entries for `TLSv1_1_client_method`, `TLSv1_2_client_method`, `TLSv1_1_server_method`, `TLSv1_2_server_method`.
  - Added `RESOLVEFUNC(...)` calls to resolve the new methods by name (works on Windows too with the standard resolver path).
- `src/network/ssl/qsslsocket_openssl.cpp`:
  - `QSslCipher_from_SSL_CIPHER(...)` now maps “TLSv1.1” and “TLSv1.2” to the new enums.
  - In `initSslContext()`, for `TlsV1_1` and `TlsV1_2`, uses `SSLv23_*_method()` and sets `SSL_OP_NO_SSLv2|SSL_OP_NO_SSLv3|SSL_OP_NO_TLSv1[|SSL_OP_NO_TLSv1_1]` to enforce minimum version.
  - Leaves existing behavior unchanged for other protocol selections.

## Build Instructions (MinGW 4.4, OpenSSL 1.0.2u)

### Option A — dynamic OpenSSL (recommended with your DLLs)

- This uses Qt’s runtime resolver (no link to import libs needed).
- Build Qt normally after the patch:
  - Clean QtNetwork to be safe: `mingw32-make -C src/network clean`
  - Rebuild: from repo root, run `configure -platform win32-g++ -opensource -confirm-license` then `mingw32-make` (or rebuild just QtNetwork and its deps).
- At runtime, ensure `ssleay32.dll` and `libeay32.dll` from your 1.0.2u build are on PATH or next to your application executable at runtime.

### Option B — link against OpenSSL

- Requires import libs in your OpenSSL folder (e.g., `libssl.dll.a`, `libcrypto.dll.a` or MinGW-named equivalents).
- Configure Qt to link:
  - Example: `configure -platform win32-g++ -opensource -confirm-license -openssl-linked -I C:\Users\Liki\Repos\openssl-1.0.2u-symbian\include -L C:\Users\Liki\Repos\openssl-1.0.2u-symbian\lib`
  - Then `mingw32-make`
- Deploy the matching DLLs with your application.

## Usage

- Default remains legacy (SslV3). Prefer explicitly setting:
  - `socket.setProtocol(QSsl::TlsV1_2);` to require TLS 1.2
  - or `socket.setProtocol(QSsl::AnyProtocol);` to negotiate highest available
- OpenSSL 1.0.2u does not support TLS 1.3; TLS 1.2 is the maximum.

## Verification

- Build QtNetwork and link a small test to `connectToHostEncrypted()` against a TLS 1.2-only endpoint.
- Connect to a TLS 1.2-only server and check
  `QSslSocket::sessionCipher().protocol()` returns `QSsl::TlsV1_2` or `TlsV1_1` as applicable.
- Ensure your `ssleay32.dll`/`libeay32.dll` are from 1.0.2u and load first at runtime (no older DLLs earlier in PATH).

## Notes

- OpenSSL 1.0.2u supports up to TLS 1.2 (not TLS 1.3).
- `SSL_OP_NO_TLSv1_1` and `SSL_OP_NO_TLSv1_2` are defined if absent to compile
  on older headers; they are no-ops if the runtime lacks those options.

## Apply patches later

From the Qt source root, with GNU patch:

```bash
patch -p1 < diff/qssl.h.diff
patch -p1 < diff/qsslsocket_openssl_symbols_p.h.diff
patch -p1 < diff/qsslsocket_openssl_symbols.cpp.diff
patch -p1 < diff/qsslsocket_openssl.cpp.diff
```

Or

```bash
patch -p1 < diff/combined_tls.patch
```

Or

```ps
powershell -ExecutionPolicy Bypass -File diff\apply_combined_tls.ps1
```

## Switch

### Approach 1: Keep Conservative Default

- Behavior: Default remains legacy `QSsl::SslV3`. Apps opt-in to TLS 1.1/1.2 by calling `setProtocol(QSsl::TlsV1_1)` or `setProtocol(QSsl::TlsV1_2)`, or use `AnyProtocol` to negotiate.
- Code changes: No additional code changes beyond the TLS 1.1/1.2 backport you already have.
- Docs: No change.

### Approach 2: Switch Default To AnyProtocol

- Behavior: Default changes to `QSsl::AnyProtocol` so Qt negotiates the highest version supported (including TLS 1.1/1.2 with OpenSSL 1.0.2u) without app changes.
- Code changes: Small, targeted updates in the configuration default and documentation.

Patch file: `diff/switch_default_to_anyprotocol.patch`

Apply:

- If you have GNU patch: `patch -p1 < diff/switch_default_to_anyprotocol.patch`
- Or with Git: `git apply --reject --whitespace=fix diff/switch_default_to_anyprotocol.patch`

### Recommendation

- If you want drop-in modern behavior for apps you can’t modify, use Approach 2 (switch default).
- If you prefer API conservatism and explicit control per app, use Approach 1.
