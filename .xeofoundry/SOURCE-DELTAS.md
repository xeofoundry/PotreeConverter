# Source deltas required by this fork

The build requires small fixes to the upstream `Converter/` sources so they compile under C++23. They are shaped for upstream delivery and can be deleted once upstream merges them. The module rename below is local and permanent, not for upstream delivery.

## Portable debug break

- Files: `Converter/modules/helpers/helpers.hpp`, `Converter/src/VBuffer.cpp`, `Converter/src/indexer.cpp`
- Delta: add `HELPERS_DEBUG_BREAK()` (maps to `__debugbreak()` on MSVC, `__builtin_trap()` elsewhere) and use it at the three unconditional call sites.
- Rationale: `__debugbreak()` is MSVC-only; clang and g++ reject it. `-fms-extensions` only helps clang and is not a source contribution.

## Explicit json string extraction

- File: `Converter/src/indexer.cpp`
- Delta: use `.get<std::string>()` for the four `std::string` assignments from `nlohmann::json`.
- Rationale: the implicit `std::string = json` assignment is ambiguous under C++23 with vendored nlohmann json 3.7.3. The vendored json library is not touched.

## Portable 64-bit seek

- File: `Converter/modules/helpers/helpers.hpp`
- Delta: replace the `constexpr` function-pointer aliases for the 64-bit `fseek` with an inline wrapper that calls `fseeko64` on Linux and `_fseeki64` on Windows.
- Rationale: clang-cl rejects a `constexpr` initialised from the address of a `__declspec(dllimport)` function, so `constexpr auto fseek_64_all_platforms = _fseeki64;` fails to compile on Windows. The wrapper never takes the address, and the call sites are unchanged.

## Local module rename

- Rename: `Converter/modules/unsuck/` to `Converter/modules/helpers/`, `unsuck.hpp` to `helpers.hpp`, `unsuck_platform_specific.cpp` to `helpers_platform_specific.cpp`, and `UNSUCK_DEBUG_BREAK` to `HELPERS_DEBUG_BREAK`.
- Rationale: the upstream module name is informal.
- This is a deliberate, permanent divergence from upstream and is not intended for upstream delivery. Merging upstream will not revert it.

## Delete when upstream merges

Delete this file and revert the upstream-shaped deltas above once those fixes are merged upstream. The module rename is local and is not reverted by that merge.
