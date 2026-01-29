# Low-level FFI bindings for libmemvid.
#
# This module provides direct bindings to the C FFI layer.
# For most use cases, prefer the high-level `Memvid::Memory` class.

@[Link("memvid")]
lib LibMemvid
  # Error codes matching memvid-core error variants.
  # Codes 1-99 map to core errors, 100+ are FFI-specific.
  enum ErrorCode : Int32
    Ok                    =   0
    Io                    =   1
    Encode                =   2
    Decode                =   3
    Lock                  =   4
    Locked                =   5
    ChecksumMismatch      =   6
    InvalidHeader         =   7
    EncryptedFile         =   8
    InvalidToc            =   9
    InvalidTimeIndex      =  10
    LexNotEnabled         =  11
    VecNotEnabled         =  12
    ClipNotEnabled        =  13
    VecDimensionMismatch  =  14
    InvalidSketchTrack    =  15
    InvalidLogicMesh      =  16
    LogicMeshNotEnabled   =  17
    NerModelNotAvailable  =  18
    InvalidTier           =  21
    TicketSequence        =  22
    TicketRequired        =  23
    CapacityExceeded      =  24
    ApiKeyRequired        =  25
    MemoryAlreadyBound    =  26
    RequiresSealed        =  31
    RequiresOpen          =  32
    DoctorNoOp            =  33
    Doctor                =  34
    FeatureUnavailable    =  41
    InvalidCursor         =  42
    InvalidFrame          =  43
    FrameNotFound         =  44
    FrameNotFoundByUri    =  45
    InvalidQuery          =  46
    TicketSignatureInvalid = 51
    ModelSignatureInvalid  = 52
    ModelManifestInvalid   = 53
    ModelIntegrity         = 54
    ExtractionFailed       = 61
    EmbeddingFailed        = 62
    RerankFailed           = 63
    Tantivy                = 64
    TableExtraction        = 65
    SchemaValidation       = 66
    WalCorruption          = 71
    ManifestWalCorrupted   = 72
    CheckpointFailed       = 73
    AuxiliaryFileDetected  = 74
    NullPointer            = 100
    InvalidUtf8            = 101
    JsonParse              = 102
    InvalidHandle          = 103
    Unknown                = 255
  end

  # Feature flags bitmask.
  @[Flags]
  enum Features : UInt32
    Lex  = 0x01
    Vec  = 0x02
    Clip = 0x04
  end

  # Opaque handle to a Memvid instance.
  type Handle = Void*

  # Error structure returned via out-parameter.
  struct Error
    code : ErrorCode
    message : LibC::Char*
  end

  # Memory statistics structure.
  struct Stats
    frame_count : UInt64
    active_frame_count : UInt64
    size_bytes : UInt64
    payload_bytes : UInt64
    logical_bytes : UInt64
    capacity_bytes : UInt64
    has_lex_index : UInt8
    has_vec_index : UInt8
    has_clip_index : UInt8
    has_time_index : UInt8
    _padding : StaticArray(UInt8, 4)
    wal_bytes : UInt64
    lex_index_bytes : UInt64
    vec_index_bytes : UInt64
    time_index_bytes : UInt64
    vector_count : UInt64
    clip_image_count : UInt64
    compression_ratio_percent : Float64
    savings_percent : Float64
    storage_utilisation_percent : Float64
    remaining_capacity_bytes : UInt64
  end

  # Version and features
  fun version = memvid_version : LibC::Char*
  fun features = memvid_features : UInt32

  # Lifecycle
  fun create = memvid_create(path : LibC::Char*, error : Error*) : Handle
  fun open = memvid_open(path : LibC::Char*, error : Error*) : Handle
  fun close = memvid_close(handle : Handle) : Void

  # Mutations
  fun put_bytes = memvid_put_bytes(
    handle : Handle,
    data : UInt8*,
    len : LibC::SizeT,
    error : Error*
  ) : UInt64

  fun put_bytes_with_options = memvid_put_bytes_with_options(
    handle : Handle,
    data : UInt8*,
    len : LibC::SizeT,
    options_json : LibC::Char*,
    error : Error*
  ) : UInt64

  fun commit = memvid_commit(handle : Handle, error : Error*) : Int32

  # Search
  fun search = memvid_search(
    handle : Handle,
    request_json : LibC::Char*,
    error : Error*
  ) : LibC::Char*

  fun string_free = memvid_string_free(str : LibC::Char*) : Void

  # State
  fun stats = memvid_stats(handle : Handle, stats : Stats*, error : Error*) : Int32
  fun frame_count = memvid_frame_count(handle : Handle, error : Error*) : UInt64

  # Frame retrieval
  fun frame_by_id = memvid_frame_by_id(
    handle : Handle,
    frame_id : UInt64,
    error : Error*
  ) : LibC::Char*

  fun frame_by_uri = memvid_frame_by_uri(
    handle : Handle,
    uri : LibC::Char*,
    error : Error*
  ) : LibC::Char*

  fun frame_content = memvid_frame_content(
    handle : Handle,
    frame_id : UInt64,
    error : Error*
  ) : LibC::Char*

  fun delete_frame = memvid_delete_frame(
    handle : Handle,
    frame_id : UInt64,
    error : Error*
  ) : UInt64

  # Timeline
  fun timeline = memvid_timeline(
    handle : Handle,
    query_json : LibC::Char*,
    error : Error*
  ) : LibC::Char*

  # Verification (static function - no handle required)
  fun verify = memvid_verify(
    path : LibC::Char*,
    deep : Int32,
    error : Error*
  ) : LibC::Char*

  # Memory management
  fun error_free = memvid_error_free(error : Error*) : Void
end
