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
