# TODO

## Completed

- [x] Phase 1: Lifecycle, mutations, search, state queries
- [x] Phase 2: Frame retrieval, timeline, verify
- [x] Phase 3: RAG/ask API, Doctor (file repair)
- [x] Comprehensive test suite (57 Crystal specs, 26 Rust FFI tests)

## Future Enhancements

### API Coverage

- [ ] CLIP image embeddings (requires `clip` feature in memvid-core)
- [ ] Vector search mode (requires `vec` feature)
- [ ] Blob reader (raw binary data access)
- [ ] Frame iteration / cursor API

### Crystal Bindings

- [ ] Add `Memory#each` iterator for frames
- [ ] Add `Memory#[]` accessor for frame by ID
- [ ] Consider lazy SearchResponse with pagination
- [ ] Thread-safety wrapper option (Mutex-based)

### Documentation

- [ ] Expand README with installation instructions
- [ ] Add usage examples for common workflows
- [ ] Document library path setup (LIBRARY_PATH, LD_LIBRARY_PATH)

### Installation & Distribution

- [ ] Create install script for libmemvid.so
- [ ] Add Makefile or justfile for building FFI + Crystal together
- [ ] Consider bundling prebuilt binaries for common platforms
- [ ] Publish to shards.info once stable

### CI/CD

- [ ] GitHub Actions workflow for Crystal specs
- [ ] Automated libmemvid.so build in CI
- [ ] Cross-platform testing (Linux, macOS)

### FFI Layer

- [ ] Fix `temporal_track` feature warnings
- [ ] Add pkg-config file for easier linking
- [ ] Consider async/callback API for long operations
