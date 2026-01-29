# TODO

## Documentation

- [ ] Expand README with installation instructions
- [ ] Add usage examples for common workflows
- [ ] Document library path setup (LIBRARY_PATH, LD_LIBRARY_PATH)
- [ ] Add API documentation comments to all public methods

## Installation & Distribution

- [ ] Create install script for libmemvid.so
- [ ] Add Makefile or justfile for building FFI + Crystal together
- [ ] Consider bundling prebuilt binaries for common platforms
- [ ] Publish to shards.info once stable

## API Coverage (Phase 2)

The following memvid-core features are not yet exposed:

- [ ] `get_frame(id)` - retrieve frame by ID
- [ ] `get_frame_by_uri(uri)` - retrieve frame by URI
- [ ] `delete_frame(id)` - soft delete a frame
- [ ] `timeline(query)` - chronological queries
- [ ] `verify(path, deep)` - file integrity verification
- [ ] Frame iteration / cursor API
- [ ] Encryption support (if enabled)

## API Coverage (Phase 3)

- [ ] `ask(query)` - RAG/LLM integration
- [ ] CLIP image embeddings (if `clip` feature enabled)
- [ ] Vector search mode (if `vec` feature enabled)
- [ ] Memory cards / export
- [ ] Doctor/repair functionality

## Crystal Bindings

- [ ] Add `Memory#each` iterator for frames
- [ ] Add `Memory#[]` accessor for frame by ID
- [ ] Consider lazy SearchResponse with pagination
- [ ] Add logging/tracing integration
- [ ] Thread-safety wrapper option (Mutex-based)

## Testing

- [ ] Add integration tests with larger datasets
- [ ] Add benchmark suite
- [ ] Test error conditions more thoroughly
- [ ] Test with vec/clip features enabled
- [ ] Memory leak detection tests

## CI/CD

- [ ] GitHub Actions workflow for Crystal specs
- [ ] Automated libmemvid.so build in CI
- [ ] Cross-platform testing (Linux, macOS)
- [ ] Release automation

## FFI Layer (memvid-ffi)

- [ ] Fix cbindgen for Rust 2024 `#[unsafe(no_mangle)]` syntax
- [ ] Add `memvid_get_frame` function
- [ ] Add `memvid_delete_frame` function
- [ ] Add `memvid_timeline` function
- [ ] Add `memvid_verify` function
- [ ] Consider async/callback API for long operations
- [ ] Add pkg-config file for easier linking

## Upstream

- [ ] Submit PR to memvid/memvid with FFI layer
- [ ] Coordinate on API stability guarantees
