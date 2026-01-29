# Feature Request: C FFI Layer for memvid-core

## Summary

Add a C-compatible FFI layer to `memvid-core` to enable bindings for languages beyond Python and Node.js. This would allow Crystal, Go, Ruby, Zig, and other languages with C interop to use memvid natively.

## Motivation

I'm am thinking of building Crystal language bindings for memvid. Crystal has excellent C interop but cannot directly consume PyO3 or N-API bindings.

Looking at the existing SDK architecture:
- **Python SDK**: PyO3 bindings → `memvid_sdk` wheels
- **Node.js SDK**: N-API bindings → `memvid_sdk.node`

Both bind to the same Rust core. A C FFI layer would be a natural third target that unlocks many additional languages:

| Language | C Interop Method |
|----------|------------------|
| Crystal | `lib` declarations |
| Go | cgo |
| Ruby | FFI gem |
| Zig | `@cImport` |
| Dart | dart:ffi |
| Lua | LuaJIT FFI |
| PHP | FFI extension |

## Proposed Approach

### 1. Add cdylib target to Cargo.toml

```toml
[lib]
crate-type = ["rlib", "cdylib", "staticlib"]
```

### 2. Create `src/ffi.rs` with extern "C" wrappers

A minimal viable API covering core operations:

```rust
// Opaque handle
pub struct MemvidHandle { /* ... */ }

#[no_mangle]
pub extern "C" fn memvid_open(path: *const c_char, error: *mut MemvidError) -> *mut MemvidHandle;

#[no_mangle]
pub extern "C" fn memvid_close(handle: *mut MemvidHandle);

#[no_mangle]
pub extern "C" fn memvid_create(path: *const c_char, error: *mut MemvidError) -> *mut MemvidHandle;

#[no_mangle]
pub extern "C" fn memvid_put(
    handle: *mut MemvidHandle,
    json_data: *const c_char,  // JSON-encoded PutRequest
    error: *mut MemvidError
) -> *mut c_char;  // JSON-encoded result, caller must free

#[no_mangle]
pub extern "C" fn memvid_find(
    handle: *mut MemvidHandle,
    query: *const c_char,
    k: u32,
    mode: *const c_char,  // "hybrid", "lex", "vec"
    error: *mut MemvidError
) -> *mut c_char;  // JSON-encoded SearchResponse

#[no_mangle]
pub extern "C" fn memvid_state(handle: *mut MemvidHandle) -> *mut c_char;

#[no_mangle]
pub extern "C" fn memvid_free_string(s: *mut c_char);

// Error handling
#[repr(C)]
pub struct MemvidError {
    pub code: *mut c_char,     // e.g., "MV001"
    pub message: *mut c_char,
}

#[no_mangle]
pub extern "C" fn memvid_error_free(error: *mut MemvidError);
```

### 3. Generate C header via cbindgen

```toml
# cbindgen.toml
language = "C"
include_guard = "MEMVID_H"
```

This produces a `memvid.h` that any C-compatible language can consume.

## API Design Considerations

**Opaque handles**: Keep `MemvidHandle` opaque to allow internal refactoring without breaking ABI.

**Error handling**: Use out-parameter error structs rather than return codes to preserve error details (code + message).

**Memory ownership**: Document clearly who owns/frees each allocation. Provide `memvid_free_string()` for all returned strings.

**JSON for complex types**: Perhaps rather than defining C structs for every type (SearchRequest, Frame, DocMetadata, etc.), passing JSON strings could keep the FFI surface minimal while preserving full functionality. The small serialization overhead is negligible compared to actual search/embedding operations.

## Scope Suggestion

A minimal first release could cover just the core operations (~10 functions):

1. `memvid_open` / `memvid_close` / `memvid_create`
2. `memvid_put` / `memvid_put_many`
3. `memvid_find` / `memvid_vec_search`
4. `memvid_state` / `memvid_stats`
5. `memvid_free_string` / `memvid_error_free`

Advanced features (sessions, memory cards, tables, cloud binding) could follow.

## Contribution Offer

I'm happy to contribute to this effort if you're open to it. I have some experience with Rust FFI and would be maintaining Crystal bindings downstream.

## Questions

1. Is the binding code (PyO3/napi-rs wrappers) in a separate private repo, or generated during build?
2. Would you prefer C FFI in the main repo or a separate `memvid-ffi` crate?
3. Any concerns about ABI stability commitments?

## Related

- Crystal language: https://crystal-lang.org/reference/syntax_and_semantics/c_bindings/
- cbindgen: https://github.com/mozilla/cbindgen
- Rust FFI guide: https://doc.rust-lang.org/nomicon/ffi.html

