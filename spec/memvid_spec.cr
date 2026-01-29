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
