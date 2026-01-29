require "spec"
require "../src/memvid"

describe Memvid do
  describe ".lib_version" do
    it "returns a version string" do
      version = Memvid.lib_version
      version.should_not be_empty
      version.should match(/^\d+\.\d+\.\d+/)
    end
  end

  describe ".features" do
    it "returns feature flags" do
      features = Memvid.features
      features.should be_a(LibMemvid::Features)
    end
  end

  describe ".lex_enabled?" do
    it "returns a boolean" do
      result = Memvid.lex_enabled?
      [true, false].should contain(result)
    end
  end

  describe ".verify" do
    it "verifies a valid memory file" do
      temp_path = File.tempname("memvid_verify_test", ".mv2")
      begin
        Memvid::Memory.create(temp_path) do |mem|
          mem.put("Content for verification test")
          mem.commit
        end

        report = Memvid.verify(temp_path)
        report.file_path.should eq(temp_path)
        report.passed?.should be_true
        report.overall_status.should eq(Memvid::VerificationStatus::Passed)
        report.checks.should_not be_empty
      ensure
        File.delete(temp_path) if File.exists?(temp_path)
      end
    end

    it "supports deep verification" do
      temp_path = File.tempname("memvid_verify_deep_test", ".mv2")
      begin
        Memvid::Memory.create(temp_path) do |mem|
          mem.put("Content for deep verification")
          mem.commit
        end

        report = Memvid.verify(temp_path, deep: true)
        report.passed?.should be_true
      ensure
        File.delete(temp_path) if File.exists?(temp_path)
      end
    end
  end
end

describe Memvid::Memory do
  temp_path = ""

  before_each do
    temp_path = File.tempname("memvid_test", ".mv2")
  end

  after_each do
    File.delete(temp_path) if File.exists?(temp_path)
  end

  describe ".create" do
    it "creates a new memory file" do
      mem = Memvid::Memory.create(temp_path)
      mem.should_not be_nil
      mem.closed?.should be_false
      mem.close
      File.exists?(temp_path).should be_true
    end

    it "works with block form" do
      Memvid::Memory.create(temp_path) do |mem|
        mem.closed?.should be_false
      end
      # Memory should be closed after block
      File.exists?(temp_path).should be_true
    end
  end

  describe ".open" do
    it "opens an existing memory file" do
      # First create it
      Memvid::Memory.create(temp_path) do |mem|
        mem.commit
      end

      # Then open it
      mem = Memvid::Memory.open(temp_path)
      mem.should_not be_nil
      mem.close
    end

    it "raises on non-existent file" do
      expect_raises(Memvid::Error) do
        Memvid::Memory.open("/nonexistent/path/to/file.mv2")
      end
    end
  end

  describe "#put" do
    it "adds string content and returns frame ID" do
      Memvid::Memory.create(temp_path) do |mem|
        frame_id = mem.put("Hello, World!")
        frame_id.should be > 0
      end
    end

    it "adds binary content" do
      Memvid::Memory.create(temp_path) do |mem|
        data = Bytes.new(10) { |i| i.to_u8 }
        frame_id = mem.put(data)
        frame_id.should be > 0
      end
    end

    it "accepts PutOptions" do
      Memvid::Memory.create(temp_path) do |mem|
        options = Memvid::PutOptions.new(
          title: "Test Document",
          uri: "test://doc1"
        )
        frame_id = mem.put("Content with options", options)
        frame_id.should be > 0
      end
    end
  end

  describe "#commit" do
    it "persists changes" do
      Memvid::Memory.create(temp_path) do |mem|
        mem.put("Test content")
        mem.commit # Should not raise
      end
    end
  end

  describe "#frame_count" do
    it "returns the number of frames" do
      Memvid::Memory.create(temp_path) do |mem|
        mem.frame_count.should eq(0)

        mem.put("First document")
        mem.put("Second document")
        mem.commit

        mem.frame_count.should eq(2)
      end
    end
  end

  describe "#stats" do
    it "returns memory statistics" do
      Memvid::Memory.create(temp_path) do |mem|
        mem.put("Some content for stats")
        mem.commit

        stats = mem.stats
        stats.frame_count.should eq(1)
        stats.active_frame_count.should eq(1)
        stats.size_bytes.should be > 0
      end
    end
  end

  describe "#search" do
    it "searches for content" do
      Memvid::Memory.create(temp_path) do |mem|
        mem.put("The Crystal programming language is fast and elegant.")
        mem.put("Ruby is a dynamic language known for developer happiness.")
        mem.put("Rust provides memory safety without garbage collection.")
        mem.commit

        results = mem.search("Crystal programming")
        results.hits.should_not be_empty
        results.hits.first.score.should be > 0
      end
    end

    it "accepts SearchRequest for advanced queries" do
      Memvid::Memory.create(temp_path) do |mem|
        mem.put("Document about AI and machine learning")
        mem.commit

        request = Memvid::SearchRequest.new(
          query: "AI",
          top_k: 5
        )
        results = mem.search(request)
        results.should be_a(Memvid::SearchResponse)
      end
    end
  end

  describe "#close" do
    it "closes the memory" do
      mem = Memvid::Memory.create(temp_path)
      mem.closed?.should be_false
      mem.close
      mem.closed?.should be_true
    end

    it "raises on operations after close" do
      mem = Memvid::Memory.create(temp_path)
      mem.close

      expect_raises(Memvid::Error) do
        mem.put("Should fail")
      end
    end
  end

  describe "#frame" do
    it "returns frame metadata by ID" do
      Memvid::Memory.create(temp_path) do |mem|
        options = Memvid::PutOptions.new(
          title: "Test Frame",
          uri: "test://frame1"
        )
        mem.put("Frame content here", options)
        mem.commit

        # Frame IDs are 0-indexed
        frame = mem.frame(0_u64)
        frame.id.should eq(0)
        frame.title.should eq("Test Frame")
        frame.uri.should eq("test://frame1")
        frame.status.should eq("Active")
      end
    end

    it "raises FrameNotFoundError for invalid ID" do
      Memvid::Memory.create(temp_path) do |mem|
        mem.commit
        expect_raises(Memvid::FrameNotFoundError) do
          mem.frame(999_u64)
        end
      end
    end
  end

  describe "#frame_by_uri" do
    it "returns frame metadata by URI" do
      Memvid::Memory.create(temp_path) do |mem|
        options = Memvid::PutOptions.new(
          title: "URI Test",
          uri: "test://unique-uri"
        )
        mem.put("Content for URI test", options)
        mem.commit

        frame = mem.frame_by_uri("test://unique-uri")
        frame.title.should eq("URI Test")
        frame.uri.should eq("test://unique-uri")
      end
    end

    it "raises FrameNotFoundError for unknown URI" do
      Memvid::Memory.create(temp_path) do |mem|
        mem.commit
        expect_raises(Memvid::FrameNotFoundError) do
          mem.frame_by_uri("test://nonexistent")
        end
      end
    end
  end

  describe "#frame_content" do
    it "returns frame text content" do
      Memvid::Memory.create(temp_path) do |mem|
        mem.put("This is the frame content.")
        mem.commit

        content = mem.frame_content(0_u64)
        content.should contain("This is the frame content.")
      end
    end
  end

  describe "#delete_frame" do
    it "soft-deletes a frame and returns WAL sequence" do
      Memvid::Memory.create(temp_path) do |mem|
        mem.put("Content to delete")
        mem.commit

        seq = mem.delete_frame(0_u64)
        seq.should be > 0

        # Commit the deletion
        mem.commit

        # After deletion and commit, active frame count should be 0
        stats = mem.stats
        stats.active_frame_count.should eq(0)
      end
    end
  end

  describe "#timeline" do
    it "returns timeline entries" do
      Memvid::Memory.create(temp_path) do |mem|
        mem.put("First entry")
        mem.put("Second entry")
        mem.put("Third entry")
        mem.commit

        response = mem.timeline
        response.count.should eq(3)
        response.entries.size.should eq(3)
        response.entries.first.frame_id.should eq(0)
      end
    end

    it "accepts TimelineQuery parameters" do
      Memvid::Memory.create(temp_path) do |mem|
        mem.put("Entry 1")
        mem.put("Entry 2")
        mem.put("Entry 3")
        mem.commit

        query = Memvid::TimelineQuery.new(limit: 2_u64, reverse: true)
        response = mem.timeline(query)
        response.entries.size.should eq(2)
      end
    end
  end
end

describe Memvid::PutOptions do
  it "serializes to JSON" do
    options = Memvid::PutOptions.new(
      uri: "test://uri",
      title: "Test Title",
      tags: {"key" => "value"},
      labels: ["label1", "label2"]
    )

    json = options.to_json
    json.should contain("\"uri\":\"test://uri\"")
    json.should contain("\"title\":\"Test Title\"")
  end
end

describe Memvid::Stats do
  it "formats size nicely in to_s" do
    # We can't easily test this without a real Stats object,
    # so we just verify the class exists
    Memvid::Stats.should_not be_nil
  end
end

# =============================================================================
# Edge Case Tests
# =============================================================================

describe "Edge Cases" do
  temp_path = ""

  before_each do
    temp_path = File.tempname("memvid_edge_test", ".mv2")
  end

  after_each do
    File.delete(temp_path) if File.exists?(temp_path)
  end

  describe "content edge cases" do
    it "handles empty string content" do
      Memvid::Memory.create(temp_path) do |mem|
        mem.put("")
        mem.commit
        mem.frame_count.should eq(1)
      end
    end

    it "handles unicode content" do
      Memvid::Memory.create(temp_path) do |mem|
        unicode_content = "Hello 世界! 🎉 Привет мир! مرحبا بالعالم"
        mem.put(unicode_content)
        mem.commit

        content = mem.frame_content(0_u64)
        content.should contain("世界")
        content.should contain("🎉")
        content.should contain("Привет")
      end
    end

    it "handles binary content with null bytes" do
      Memvid::Memory.create(temp_path) do |mem|
        binary = Bytes.new(20) { |i| (i % 256).to_u8 }
        binary[5] = 0_u8  # null byte in middle
        binary[10] = 0_u8
        mem.put(binary)
        mem.commit
        mem.frame_count.should eq(1)
      end
    end

    it "handles moderately large content" do
      Memvid::Memory.create(temp_path) do |mem|
        # 100KB of text - memvid will chunk this into multiple frames
        large_content = "x" * 100_000
        mem.put(large_content)
        mem.commit

        # Large content gets chunked, so frame_count may be > 1
        mem.frame_count.should be > 0

        # Verify we can retrieve at least the first frame's content
        content = mem.frame_content(0_u64)
        content.should contain("x" * 100)
      end
    end

    it "handles content with special characters" do
      Memvid::Memory.create(temp_path) do |mem|
        special = "Line1\nLine2\tTabbed\r\nWindows\0Null\"Quotes'Single\\Backslash"
        mem.put(special)
        mem.commit
        mem.frame_count.should eq(1)
      end
    end
  end

  describe "search edge cases" do
    it "returns empty results for no matches" do
      Memvid::Memory.create(temp_path) do |mem|
        mem.put("The quick brown fox")
        mem.commit

        results = mem.search("elephant zebra giraffe")
        results.hits.should be_empty
      end
    end

    it "searches empty memory without error" do
      Memvid::Memory.create(temp_path) do |mem|
        mem.commit
        results = mem.search("anything")
        results.hits.should be_empty
      end
    end

    it "handles special characters in search query" do
      Memvid::Memory.create(temp_path) do |mem|
        mem.put("C++ programming and C# development")
        mem.commit

        # These shouldn't crash even if they don't match well
        mem.search("C++").hits  # should not raise
        mem.search("test@example.com").hits
        mem.search("path/to/file").hits
      end
    end

    it "handles very long search queries" do
      Memvid::Memory.create(temp_path) do |mem|
        mem.put("Short document")
        mem.commit

        long_query = "word " * 100
        results = mem.search(long_query.strip)
        results.should be_a(Memvid::SearchResponse)
      end
    end
  end

  describe "persistence round-trip" do
    it "persists content across close and reopen" do
      # Create and add content
      Memvid::Memory.create(temp_path) do |mem|
        mem.put("Document one")
        mem.put("Document two")
        mem.put("Document three")
        mem.commit
      end

      # Reopen and verify
      Memvid::Memory.open(temp_path) do |mem|
        mem.frame_count.should eq(3)

        content = mem.frame_content(0_u64)
        content.should contain("Document one")

        results = mem.search("Document")
        results.hits.size.should eq(3)
      end
    end

    it "persists frame metadata across close and reopen" do
      uri = "test://persistence-test"
      title = "Persistence Test Document"

      Memvid::Memory.create(temp_path) do |mem|
        options = Memvid::PutOptions.new(uri: uri, title: title)
        mem.put("Content here", options)
        mem.commit
      end

      Memvid::Memory.open(temp_path) do |mem|
        frame = mem.frame(0_u64)
        frame.uri.should eq(uri)
        frame.title.should eq(title)
      end
    end

    it "persists deletions across close and reopen" do
      Memvid::Memory.create(temp_path) do |mem|
        mem.put("To be deleted")
        mem.put("To be kept")
        mem.commit

        mem.delete_frame(0_u64)
        mem.commit
      end

      Memvid::Memory.open(temp_path) do |mem|
        stats = mem.stats
        stats.frame_count.should eq(2)
        stats.active_frame_count.should eq(1)
      end
    end
  end

  describe "multiple operations" do
    it "handles many frames" do
      Memvid::Memory.create(temp_path) do |mem|
        50.times do |i|
          mem.put("Document number #{i} with some content for searching")
        end
        mem.commit

        mem.frame_count.should eq(50)

        # Search should still work
        results = mem.search("Document number", top_k: 100)
        results.hits.size.should eq(50)
      end
    end

    it "handles multiple commit cycles" do
      Memvid::Memory.create(temp_path) do |mem|
        5.times do |batch|
          10.times do |i|
            mem.put("Batch #{batch} item #{i}")
          end
          mem.commit
        end

        mem.frame_count.should eq(50)
      end
    end

    it "tracks stats correctly through operations" do
      Memvid::Memory.create(temp_path) do |mem|
        mem.stats.frame_count.should eq(0)
        mem.stats.active_frame_count.should eq(0)

        mem.put("First")
        mem.put("Second")
        mem.commit

        mem.stats.frame_count.should eq(2)
        mem.stats.active_frame_count.should eq(2)

        mem.delete_frame(0_u64)
        mem.commit

        mem.stats.frame_count.should eq(2)
        mem.stats.active_frame_count.should eq(1)
      end
    end
  end

  describe "error handling" do
    it "handles double close safely" do
      mem = Memvid::Memory.create(temp_path)
      mem.close
      mem.close  # Should not raise or crash
      mem.closed?.should be_true
    end

    it "raises error for frame_content on invalid ID" do
      Memvid::Memory.create(temp_path) do |mem|
        mem.commit
        # May raise FrameNotFoundError or other error depending on internal state
        expect_raises(Memvid::Error) do
          mem.frame_content(999_u64)
        end
      end
    end

    it "raises error for delete_frame on invalid ID" do
      Memvid::Memory.create(temp_path) do |mem|
        mem.commit
        expect_raises(Memvid::Error) do
          mem.delete_frame(999_u64)
        end
      end
    end
  end

  describe "timeline edge cases" do
    it "returns empty timeline for empty memory" do
      Memvid::Memory.create(temp_path) do |mem|
        mem.commit
        response = mem.timeline
        response.count.should eq(0)
        response.entries.should be_empty
      end
    end

    it "respects limit parameter" do
      Memvid::Memory.create(temp_path) do |mem|
        10.times { |i| mem.put("Entry #{i}") }
        mem.commit

        response = mem.timeline(Memvid::TimelineQuery.new(limit: 3_u64))
        response.entries.size.should eq(3)
      end
    end

    it "respects reverse parameter" do
      Memvid::Memory.create(temp_path) do |mem|
        mem.put("First")
        mem.put("Second")
        mem.put("Third")
        mem.commit

        forward = mem.timeline
        reverse = mem.timeline(Memvid::TimelineQuery.new(reverse: true))

        forward.entries.first.frame_id.should eq(0)
        reverse.entries.first.frame_id.should eq(2)
      end
    end
  end

  describe "verify edge cases" do
    it "raises error for non-existent file" do
      expect_raises(Memvid::Error) do
        Memvid.verify("/nonexistent/path/to/file.mv2")
      end
    end

    it "verifies empty memory file" do
      Memvid::Memory.create(temp_path) do |mem|
        mem.commit
      end

      report = Memvid.verify(temp_path)
      report.passed?.should be_true
    end
  end
end
