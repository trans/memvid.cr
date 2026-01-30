# memvid.cr

Crystal bindings for [memvid](https://github.com/memvid/memvid), the single-file AI memory format.

## Status

**Core API complete. Development paused.**

This library covers memvid's core local-only API (create, put, search, ask, verify, doctor). Development has been paused due to memvid's trajectory toward a SaaS model with API key requirements for advanced features.

**57 specs passing, 22 FFI functions wrapped**

## Installation

1. Build the FFI library:

   ```bash
   git clone https://github.com/trans/memvid-ffi
   cd memvid-ffi
   cargo build --release
   ```

2. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     memvid:
       github: trans/memvid.cr
   ```

3. Run `shards install`

4. Set the library path when running:

   ```bash
   LD_LIBRARY_PATH=/path/to/memvid-ffi/target/release crystal run src/myapp.cr
   ```

## Usage

```crystal
require "memvid"

# Create a new memory file
mem = Memvid::Memory.create("knowledge.mv2")

# Add content
mem.put("Crystal is a compiled language with Ruby-like syntax.")
mem.put("It features static typing and null safety.")
mem.commit

# Search
results = mem.search("What is Crystal?", top_k: 5)
results.hits.each do |hit|
  puts "#{hit.score}: #{hit.snippet}"
end

# RAG-style Q&A
response = mem.ask("What are Crystal's main features?")
puts response.answer

# Get stats
stats = mem.stats
puts "Frames: #{stats.frame_count}"

# Clean up
mem.close
```

## API Coverage

| Feature | Status |
|---------|--------|
| Create / Open / Close | Done |
| Put / Delete / Commit | Done |
| Search (lexical) | Done |
| Ask (RAG) | Done |
| Frame retrieval | Done |
| Timeline queries | Done |
| Verify / Doctor | Done |
| Memory Cards | Not implemented |
| Enrichment | Not implemented |
| CLIP / Vector search | Not implemented |

## Development

```bash
# Run specs (requires libmemvid.so in library path)
LD_LIBRARY_PATH=/path/to/memvid-ffi/target/release crystal spec
```

## License

MIT

## Contributors

- [Thomas Sawyer](https://github.com/trans) - creator and maintainer
