# Memvid - Crystal bindings for the memvid single-file AI memory library.
#
# Memvid provides a portable, single-file memory layer for AI agents,
# packaging documents, embeddings, search indices, and metadata into
# a self-contained .mv2 file.
#
# ## Example
#
# ```
# require "memvid"
#
# # Create a new memory file
# Memvid::Memory.create("./my-memory.mv2") do |mem|
#   # Add content
#   mem.put("Hello, this is a document about Crystal programming.")
#   mem.put("Another document discussing AI and machine learning.")
#
#   # Commit changes to disk
#   mem.commit
#
#   # Search for content
#   results = mem.search("Crystal programming")
#   results.hits.each do |hit|
#     puts "Found: #{hit.snippet} (score: #{hit.score})"
#   end
# end
#
# # Open existing memory
# Memvid::Memory.open("./my-memory.mv2") do |mem|
#   puts "Frame count: #{mem.frame_count}"
#   puts "Stats: #{mem.stats}"
# end
# ```

require "json"
require "./memvid/lib_memvid"

module Memvid
  VERSION = "0.1.0"

  # Returns the version of the underlying libmemvid library.
  def self.lib_version : String
    String.new(LibMemvid.version)
  end

  # Returns the features compiled into libmemvid.
  def self.features : LibMemvid::Features
    LibMemvid::Features.new(LibMemvid.features)
  end

  # Checks if lexical search is available.
  def self.lex_enabled? : Bool
    features.includes?(LibMemvid::Features::Lex)
  end

  # Checks if vector search is available.
  def self.vec_enabled? : Bool
    features.includes?(LibMemvid::Features::Vec)
  end

  # Checks if CLIP embeddings are available.
  def self.clip_enabled? : Bool
    features.includes?(LibMemvid::Features::Clip)
  end

  # Verify file integrity without opening it.
  #
  # Returns a `VerificationReport` with the results.
  def self.verify(path : String, deep : Bool = false) : VerificationReport
    error = LibMemvid::Error.new
    result_ptr = LibMemvid.verify(path, deep ? 1 : 0, pointerof(error))

    if result_ptr.null?
      Memory.raise_error(error)
    end

    begin
      result_json = String.new(result_ptr)
      VerificationReport.from_json(result_json)
    ensure
      LibMemvid.string_free(result_ptr)
    end
  end

  # Base exception for all Memvid errors.
  class Error < Exception
    getter code : LibMemvid::ErrorCode

    def initialize(@code : LibMemvid::ErrorCode, message : String? = nil)
      super(message || code.to_s)
    end
  end

  # Raised when an I/O operation fails.
  class IOError < Error; end

  # Raised when the file is locked by another process.
  class LockedError < Error; end

  # Raised when a feature is not enabled.
  class FeatureNotEnabledError < Error; end

  # Raised when a frame is not found.
  class FrameNotFoundError < Error; end

  # Raised when capacity is exceeded.
  class CapacityExceededError < Error; end

  # Raised when JSON parsing fails.
  class JSONParseError < Error; end

  # Frame metadata.
  class Frame
    include JSON::Serializable

    property id : UInt64
    property timestamp : Int64
    property kind : String?
    property uri : String?
    property title : String?
    property status : String
    property payload_length : UInt64
    property tags : Array(String)
    property labels : Array(String)
    property parent_id : UInt64?
    property chunk_index : UInt32?
    property chunk_count : UInt32?
  end

  # Timeline query parameters.
  class TimelineQuery
    include JSON::Serializable

    property limit : UInt64? = nil
    property since : Int64? = nil
    property until : Int64? = nil
    property reverse : Bool = false

    def initialize(
      @limit = nil,
      @since = nil,
      @until = nil,
      @reverse = false
    )
    end
  end

  # A timeline entry (frame summary).
  class TimelineEntry
    include JSON::Serializable

    property frame_id : UInt64
    property timestamp : Int64
    property preview : String
    property uri : String?
    property child_frames : Array(UInt64)
  end

  # Timeline query response.
  class TimelineResponse
    include JSON::Serializable

    property entries : Array(TimelineEntry)
    property count : Int32
  end

  # Verification status.
  enum VerificationStatus
    Passed
    Failed
    Skipped

    def self.from_json_string(str : String) : self
      case str
      when "passed"  then Passed
      when "failed"  then Failed
      when "skipped" then Skipped
      else raise "Unknown verification status: #{str}"
      end
    end
  end

  # A single verification check result.
  class VerificationCheck
    include JSON::Serializable

    property name : String
    @[JSON::Field(converter: Memvid::VerificationStatusConverter)]
    property status : VerificationStatus
    property details : String?
  end

  # Converter for VerificationStatus from JSON string.
  module VerificationStatusConverter
    def self.from_json(parser : JSON::PullParser) : VerificationStatus
      VerificationStatus.from_json_string(parser.read_string)
    end

    def self.to_json(value : VerificationStatus, builder : JSON::Builder) : Nil
      builder.string(value.to_s.downcase)
    end
  end

  # Verification report.
  class VerificationReport
    include JSON::Serializable

    property file_path : String
    @[JSON::Field(key: "overall_status", converter: Memvid::VerificationStatusConverter)]
    property overall_status : VerificationStatus
    property checks : Array(VerificationCheck)

    # Returns true if verification passed.
    def passed? : Bool
      overall_status.passed?
    end

    # Returns true if verification failed.
    def failed? : Bool
      overall_status.failed?
    end

    # Returns checks that failed.
    def failed_checks : Array(VerificationCheck)
      checks.select(&.status.failed?)
    end
  end

  # Options for `Memory#put`.
  class PutOptions
    include JSON::Serializable

    property uri : String? = nil
    property title : String? = nil
    property timestamp : Int64? = nil
    property track : String? = nil
    property kind : String? = nil
    property tags : Hash(String, String)? = nil
    property labels : Array(String)? = nil
    property search_text : String? = nil
    property auto_tag : Bool? = nil
    property extract_dates : Bool? = nil
    property extract_triplets : Bool? = nil
    property no_raw : Bool? = nil
    property dedup : Bool? = nil

    def initialize(
      @uri = nil,
      @title = nil,
      @timestamp = nil,
      @track = nil,
      @kind = nil,
      @tags = nil,
      @labels = nil,
      @search_text = nil,
      @auto_tag = nil,
      @extract_dates = nil,
      @extract_triplets = nil,
      @no_raw = nil,
      @dedup = nil
    )
    end
  end

  # Search request parameters.
  class SearchRequest
    include JSON::Serializable

    property query : String
    property top_k : Int32 = 10
    property offset : Int32 = 0
    property track : String? = nil
    property mode : String? = nil

    def initialize(
      @query : String,
      @top_k = 10,
      @offset = 0,
      @track = nil,
      @mode = nil
    )
    end
  end

  # A single search result hit.
  class SearchHit
    include JSON::Serializable

    property frame_id : UInt64
    property score : Float64
    property snippet : String?
    property uri : String?
    property title : String?
  end

  # Search results.
  class SearchResponse
    include JSON::Serializable

    property hits : Array(SearchHit)
    property total : Int64?

    # Returns the total count, defaulting to hits count if not provided.
    def total! : Int64
      @total || hits.size.to_i64
    end
  end

  # Memory statistics.
  class Stats
    getter frame_count : UInt64
    getter active_frame_count : UInt64
    getter size_bytes : UInt64
    getter payload_bytes : UInt64
    getter logical_bytes : UInt64
    getter capacity_bytes : UInt64
    getter has_lex_index : Bool
    getter has_vec_index : Bool
    getter has_clip_index : Bool
    getter has_time_index : Bool
    getter wal_bytes : UInt64
    getter lex_index_bytes : UInt64
    getter vec_index_bytes : UInt64
    getter time_index_bytes : UInt64
    getter vector_count : UInt64
    getter clip_image_count : UInt64
    getter compression_ratio_percent : Float64
    getter savings_percent : Float64
    getter storage_utilisation_percent : Float64
    getter remaining_capacity_bytes : UInt64

    def initialize(raw : LibMemvid::Stats)
      @frame_count = raw.frame_count
      @active_frame_count = raw.active_frame_count
      @size_bytes = raw.size_bytes
      @payload_bytes = raw.payload_bytes
      @logical_bytes = raw.logical_bytes
      @capacity_bytes = raw.capacity_bytes
      @has_lex_index = raw.has_lex_index != 0
      @has_vec_index = raw.has_vec_index != 0
      @has_clip_index = raw.has_clip_index != 0
      @has_time_index = raw.has_time_index != 0
      @wal_bytes = raw.wal_bytes
      @lex_index_bytes = raw.lex_index_bytes
      @vec_index_bytes = raw.vec_index_bytes
      @time_index_bytes = raw.time_index_bytes
      @vector_count = raw.vector_count
      @clip_image_count = raw.clip_image_count
      @compression_ratio_percent = raw.compression_ratio_percent
      @savings_percent = raw.savings_percent
      @storage_utilisation_percent = raw.storage_utilisation_percent
      @remaining_capacity_bytes = raw.remaining_capacity_bytes
    end

    def to_s(io : IO) : Nil
      io << "Stats("
      io << "frames: " << @frame_count
      io << ", active: " << @active_frame_count
      io << ", size: " << format_bytes(@size_bytes)
      io << ", compression: " << @compression_ratio_percent.round(1) << "%"
      io << ")"
    end

    private def format_bytes(bytes : UInt64) : String
      if bytes < 1024
        "#{bytes}B"
      elsif bytes < 1024 * 1024
        "#{(bytes / 1024.0).round(1)}KB"
      elsif bytes < 1024 * 1024 * 1024
        "#{(bytes / (1024.0 * 1024.0)).round(1)}MB"
      else
        "#{(bytes / (1024.0 * 1024.0 * 1024.0)).round(1)}GB"
      end
    end
  end

  # A single-file AI memory store.
  #
  # Memory provides a high-level interface for storing and searching
  # content in a memvid .mv2 file.
  class Memory
    @handle : LibMemvid::Handle
    @closed : Bool = false

    # Creates a new memory file at the specified path.
    #
    # Raises `Error` if the file cannot be created.
    def self.create(path : String) : Memory
      error = LibMemvid::Error.new
      handle = LibMemvid.create(path, pointerof(error))

      if handle.null?
        raise_error(error)
      end

      Memory.new(handle)
    end

    # Creates a new memory file and yields it to the block.
    # The memory is automatically closed when the block returns.
    def self.create(path : String, & : Memory ->) : Nil
      mem = create(path)
      begin
        yield mem
      ensure
        mem.close
      end
    end

    # Opens an existing memory file.
    #
    # Raises `Error` if the file cannot be opened.
    def self.open(path : String) : Memory
      error = LibMemvid::Error.new
      handle = LibMemvid.open(path, pointerof(error))

      if handle.null?
        raise_error(error)
      end

      Memory.new(handle)
    end

    # Opens an existing memory file and yields it to the block.
    # The memory is automatically closed when the block returns.
    def self.open(path : String, & : Memory ->) : Nil
      mem = open(path)
      begin
        yield mem
      ensure
        mem.close
      end
    end

    protected def initialize(@handle : LibMemvid::Handle)
    end

    # Closes the memory handle.
    #
    # After calling this method, the Memory instance is no longer usable.
    # This is called automatically when using the block forms of `create` or `open`.
    def close : Nil
      return if @closed
      LibMemvid.close(@handle)
      @closed = true
    end

    # Adds string content to the memory.
    #
    # Returns the frame ID of the newly created frame.
    def put(content : String, options : PutOptions? = nil) : UInt64
      put(content.to_slice, options)
    end

    # Adds binary content to the memory.
    #
    # Returns the frame ID of the newly created frame.
    def put(data : Bytes, options : PutOptions? = nil) : UInt64
      check_closed!
      error = LibMemvid::Error.new

      frame_id = if options
        json = options.to_json
        LibMemvid.put_bytes_with_options(@handle, data, data.size, json, pointerof(error))
      else
        LibMemvid.put_bytes(@handle, data, data.size, pointerof(error))
      end

      if frame_id == 0 && error.code != LibMemvid::ErrorCode::Ok
        Memory.raise_error(error)
      end

      frame_id
    end

    # Commits pending changes to disk.
    #
    # This should be called after adding content to ensure it is persisted.
    def commit : Nil
      check_closed!
      error = LibMemvid::Error.new
      result = LibMemvid.commit(@handle, pointerof(error))

      if result == 0
        Memory.raise_error(error)
      end
    end

    # Searches the memory with the given query string.
    #
    # This is a convenience method that creates a SearchRequest with defaults.
    def search(query : String, top_k : Int32 = 10) : SearchResponse
      search(SearchRequest.new(query: query, top_k: top_k))
    end

    # Searches the memory with a SearchRequest.
    def search(request : SearchRequest) : SearchResponse
      check_closed!
      error = LibMemvid::Error.new
      json = request.to_json

      result_ptr = LibMemvid.search(@handle, json, pointerof(error))

      if result_ptr.null?
        Memory.raise_error(error)
      end

      begin
        result_json = String.new(result_ptr)
        SearchResponse.from_json(result_json)
      ensure
        LibMemvid.string_free(result_ptr)
      end
    end

    # Returns memory statistics.
    def stats : Stats
      check_closed!
      raw_stats = LibMemvid::Stats.new
      error = LibMemvid::Error.new
      result = LibMemvid.stats(@handle, pointerof(raw_stats), pointerof(error))

      if result == 0
        Memory.raise_error(error)
      end

      Stats.new(raw_stats)
    end

    # Returns the number of frames in the memory.
    def frame_count : UInt64
      check_closed!
      error = LibMemvid::Error.new
      count = LibMemvid.frame_count(@handle, pointerof(error))

      if count == 0 && error.code != LibMemvid::ErrorCode::Ok
        Memory.raise_error(error)
      end

      count
    end

    # Gets frame metadata by ID.
    #
    # Raises `FrameNotFoundError` if the frame does not exist.
    def frame(id : UInt64) : Frame
      check_closed!
      error = LibMemvid::Error.new
      result_ptr = LibMemvid.frame_by_id(@handle, id, pointerof(error))

      if result_ptr.null?
        Memory.raise_error(error)
      end

      begin
        result_json = String.new(result_ptr)
        Frame.from_json(result_json)
      ensure
        LibMemvid.string_free(result_ptr)
      end
    end

    # Gets frame metadata by URI.
    #
    # Raises `FrameNotFoundError` if no frame with the given URI exists.
    def frame_by_uri(uri : String) : Frame
      check_closed!
      error = LibMemvid::Error.new
      result_ptr = LibMemvid.frame_by_uri(@handle, uri, pointerof(error))

      if result_ptr.null?
        Memory.raise_error(error)
      end

      begin
        result_json = String.new(result_ptr)
        Frame.from_json(result_json)
      ensure
        LibMemvid.string_free(result_ptr)
      end
    end

    # Gets the text content of a frame by ID.
    #
    # Raises `FrameNotFoundError` if the frame does not exist.
    def frame_content(id : UInt64) : String
      check_closed!
      error = LibMemvid::Error.new
      result_ptr = LibMemvid.frame_content(@handle, id, pointerof(error))

      if result_ptr.null?
        Memory.raise_error(error)
      end

      begin
        String.new(result_ptr)
      ensure
        LibMemvid.string_free(result_ptr)
      end
    end

    # Soft-deletes a frame.
    #
    # The frame data is not immediately removed; a tombstone entry is created.
    # Returns the WAL sequence number.
    #
    # Raises `FrameNotFoundError` if the frame does not exist.
    def delete_frame(id : UInt64) : UInt64
      check_closed!
      error = LibMemvid::Error.new
      seq = LibMemvid.delete_frame(@handle, id, pointerof(error))

      if seq == 0 && error.code != LibMemvid::ErrorCode::Ok
        Memory.raise_error(error)
      end

      seq
    end

    # Queries the timeline (chronological frame list).
    #
    # Returns frames in chronological order (or reverse if specified).
    def timeline(query : TimelineQuery? = nil) : TimelineResponse
      check_closed!
      error = LibMemvid::Error.new
      json = query.try(&.to_json)

      result_ptr = LibMemvid.timeline(@handle, json, pointerof(error))

      if result_ptr.null?
        Memory.raise_error(error)
      end

      begin
        result_json = String.new(result_ptr)
        TimelineResponse.from_json(result_json)
      ensure
        LibMemvid.string_free(result_ptr)
      end
    end

    # Returns true if the memory has been closed.
    def closed? : Bool
      @closed
    end

    # Finalizer to ensure the handle is closed.
    def finalize
      close unless @closed
    end

    private def check_closed!
      raise Error.new(LibMemvid::ErrorCode::InvalidHandle, "Memory is closed") if @closed
    end

    # :nodoc:
    protected def self.raise_error(error : LibMemvid::Error) : NoReturn
      message = if error.message.null?
        nil
      else
        msg = String.new(error.message)
        LibMemvid.error_free(pointerof(error))
        msg
      end

      exception = case error.code
      when .io?
        IOError.new(error.code, message)
      when .locked?, .lock?
        LockedError.new(error.code, message)
      when .lex_not_enabled?, .vec_not_enabled?, .clip_not_enabled?, .feature_unavailable?
        FeatureNotEnabledError.new(error.code, message)
      when .frame_not_found?, .frame_not_found_by_uri?
        FrameNotFoundError.new(error.code, message)
      when .capacity_exceeded?
        CapacityExceededError.new(error.code, message)
      when .json_parse?
        JSONParseError.new(error.code, message)
      else
        Error.new(error.code, message)
      end

      raise exception
    end
  end
end
