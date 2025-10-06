# OpenSSL 1.0.2u modified for Qt on Symbian^3

Copy modified sources/headers from [`openssl-symbian`](https://github.com/shinovon/openssl-symbian) into the official tree, but do NOT overwrite generated config headers or build files:

Example robocopy (PowerShell/cmd), adjust <openssl-symbian> and <openssl>:

1. `robocopy <openssl-symbian>\src\crypto <openssl>\crypto /E /XF Makefile* opensslconf.h`
1. `robocopy <openssl-symbian>\src\ssl <openssl>\ssl /E /XF Makefile*`
1. `robocopy <openssl-symbian>\inc\include\openssl <openssl>\include\openssl \*.h /XF opensslconf.h`

### What I changed:

Patched headers to handle Symbian macros and fixed an ARM-only shim that broke MinGW, then built the libs and produced the Qt 4–style DLLs.

- `ms\mingw32.bat`: emits `ssleay32.dll` and `out\libssleay32.a` instead of `libssl32.dll`.
- `include\openssl\e_os2.h:328`: defines `IMPORT_C/EXPORT_C` as no-ops for non‑Symbian builds.
- `outinc\openssl\e_os2.h`: same no-op defines so current build picks them up.
- `outinc\openssl\opensslconf.h`: adds no-op `IMPORT_C/EXPORT_C` to cover headers that include `opensslconf.h` only (e.g., `aes.h`).
- `crypto\cryptlib.c`: restricts ARM EABI helpers to Symbian/ARM only to avoid unresolved `__aeabi_*` on MinGW.

### Build commands (what I ran)

- Used Qt SDK MinGW: prepended `C:\Symbian\QtSDK\mingw\bin` to PATH for the session.
- Built static libs: `mingw32-make -f ms/mingw32a.mak` (after the fixes above).
- Wrapped DLLs:
  - `dllwrap --dllname libeay32.dll --output-lib out/libeay32.a --def ms/libeay32.def out/libcrypto.a -lws2_32 -lgdi32`
  - `dllwrap --dllname ssleay32.dll --output-lib out/libssleay32.a --def ms/ssleay32.def out/libssl.a out/libeay32.a`

`mingw32.bat`

### Outputs

- DLLs (repo root): `libeay32.dll`, `ssleay32.dll`
- Import libs: `out\libeay32.a`, `out\libssleay32.a`
- Static libs: `out\libcrypto.a`, `out\libssl.a`
- Tools/tests were also built (e.g., `openssl.exe` , various `*test.exe`)

### How to link in Qt 4 Simulator

- Include path: INCLUDEPATH += C:\Users\Liki\Repos\openssl-1.0.2u-symbian\outinc
- Libs: LIBS += -LC:\Users\Liki\Repos\openssl-1.0.2u-symbian\out -lssleay32 -leay32
- Runtime: place `ssleay32.dll` and `libeay32.dll` alongside your simulator app or in the simulator’s `bin` directory (or add repo root to PATH).

### Others

`$env:PATH = "C:\Symbian\QtSDK\mingw\bin;$env:PATH"`
