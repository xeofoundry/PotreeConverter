# Source deltas required by this fork

The build requires small fixes to the upstream `Converter/` sources so they compile under C++23. They are shaped for upstream delivery and can be deleted once upstream merges them.

## Portable debug break

- Files: `Converter/modules/unsuck/unsuck.hpp`, `Converter/src/VBuffer.cpp`, `Converter/src/indexer.cpp`
- Delta: add `UNSUCK_DEBUG_BREAK()` (maps to `__debugbreak()` on MSVC, `__builtin_trap()` elsewhere) and use it at the three unconditional call sites.
- Rationale: `__debugbreak()` is MSVC-only; clang and g++ reject it. `-fms-extensions` only helps clang and is not a source contribution.

## Explicit json string extraction

- File: `Converter/src/indexer.cpp`
- Delta: use `.get<std::string>()` for the four `std::string` assignments from `nlohmann::json`.
- Rationale: the implicit `std::string = json` assignment is ambiguous under C++23 with vendored nlohmann json 3.7.3. The vendored json library is not touched.

## Delete when upstream merges

Delete this file and revert the deltas above once both fixes are merged upstream.
