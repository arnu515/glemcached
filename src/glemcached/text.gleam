import gleam/bit_array.{byte_size}
import gleam/option.{type Option, None, Some}
import glemcached/internal/text.{
  type Value, type ValueCas, Add, Append, Cas, Decr, Delete, Deleted, Exists,
  Get, GetAndTouch, GetAndTouchs, Gets, Incr, NotFound, NotStored, Prepend,
  RawValue, Replace, Set, StorageCommand, Stored, Touch, Touched, Values,
  ValuesCas, run_text_command,
}
import glemcached/types.{
  type Memcached, type MemcachedError, CommandError, GeneralError,
}

// Storage commands

/// Stores this data in memcached. Overrides existing data if any. 
///
/// # Example
///
/// ```gleam
/// set(
///   mem,
///   key: "foo",
///   flags: flag.bit_array_to_uint16(<<1234>>),
///   exptime: 100,
///   data: <<"Hello, world!">>,
/// )
/// |> should.be_ok()
/// |> should.equal(Nil)
/// ```
pub fn set(
  mem: Memcached,
  key key: String,
  flags flags: Int,
  exptime exptime: Int,
  data data: BitArray,
) -> Result(Nil, MemcachedError) {
  case
    StorageCommand(
      cmd: Set,
      key:,
      flags:,
      exptime:,
      size: byte_size(data),
      data:,
    )
    |> run_text_command(mem, _, False)
  {
    Ok(res) ->
      case res {
        Stored -> Ok(Nil)
        // this should NEVER happen
        _ -> Error(CommandError(GeneralError))
      }
    Error(e) -> Error(e)
  }
}

/// Sets this key in Memcached only if it doesn't already exist.
/// Returns True if the value was set, and False if not (i.e. the key already exists).
/// Errors are only returned if the command fails to run.
///
/// # Example
///
/// ```gleam
/// add(
///   mem,
///   key: "foo",
///   flags: flag.bit_array_to_uint16(<<1234>>),
///   exptime: 100,
///   data: <<"Hello, world!">>,
/// )
/// ```
pub fn add(
  mem: Memcached,
  key key: String,
  flags flags: Int,
  exptime exptime: Int,
  data data: BitArray,
) -> Result(Bool, MemcachedError) {
  case
    StorageCommand(
      cmd: Add,
      key:,
      flags:,
      exptime:,
      size: byte_size(data),
      data:,
    )
    |> run_text_command(mem, _, False)
  {
    Ok(res) ->
      case res {
        Stored -> Ok(True)
        NotStored -> Ok(False)
        _ -> Error(CommandError(GeneralError))
      }
    Error(e) -> Error(e)
  }
}

/// Sets this key in Memcached only if it does already exist.
/// Returns True if the value was set, and False if not (i.e. the key does not exist).
/// Errors are only returned if the command fails to run.
///
/// # Example
///
/// ```gleam
/// replace(
///   mem,
///   key: "foo",
///   flags: flag.bit_array_to_uint16(<<1234>>),
///   exptime: 100,
///   data: <<"Hello, world!">>,
/// )
/// ```
pub fn replace(
  mem: Memcached,
  key key: String,
  flags flags: Int,
  exptime exptime: Int,
  data data: BitArray,
) -> Result(Bool, MemcachedError) {
  case
    StorageCommand(
      cmd: Replace,
      key:,
      flags:,
      exptime:,
      size: byte_size(data),
      data:,
    )
    |> run_text_command(mem, _, False)
  {
    Ok(res) ->
      case res {
        Stored -> Ok(True)
        NotStored -> Ok(False)
        _ -> Error(CommandError(GeneralError))
      }
    Error(e) -> Error(e)
  }
}

/// Adds this value to the end of the existing data.
/// Returns True if the value was set, and False if not (i.e. the key does not exist).
/// Errors are only returned if the command fails to run.
///
/// # Example
///
/// ```gleam
/// append(
///   mem,
///   key: "foo",
///   flags: flag.bit_array_to_uint16(<<1234>>),
///   exptime: 100,
///   data: <<"Hi!">>,
/// )
/// ```
pub fn append(
  mem: Memcached,
  key key: String,
  flags flags: Int,
  exptime exptime: Int,
  data data: BitArray,
) -> Result(Bool, MemcachedError) {
  case
    StorageCommand(
      cmd: Append,
      key:,
      flags:,
      exptime:,
      size: byte_size(data),
      data:,
    )
    |> run_text_command(mem, _, False)
  {
    Ok(res) ->
      case res {
        Stored -> Ok(True)
        NotStored -> Ok(False)
        _ -> Error(CommandError(GeneralError))
      }
    Error(e) -> Error(e)
  }
}

/// Adds this value to the start of the existing data.
/// Returns True if the value was set, and False if not (i.e. the key does not exist).
/// Errors are only returned if the command fails to run.
///
/// # Example
///
/// ```gleam
/// prepend(
///   mem,
///   key: "foo",
///   flags: flag.bit_array_to_uint16(<<1234>>),
///   exptime: 100,
///   data: <<"Hi!">>,
/// )
/// ```
pub fn prepend(
  mem: Memcached,
  key key: String,
  flags flags: Int,
  exptime exptime: Int,
  data data: BitArray,
) -> Result(Bool, MemcachedError) {
  case
    StorageCommand(
      cmd: Prepend,
      key:,
      flags:,
      exptime:,
      size: byte_size(data),
      data:,
    )
    |> run_text_command(mem, _, False)
  {
    Ok(res) ->
      case res {
        Stored -> Ok(True)
        NotStored -> Ok(False)
        _ -> Error(CommandError(GeneralError))
      }
    Error(e) -> Error(e)
  }
}

/// The result returned by the `cas` command. Since it has three possible
/// values, it is not possible to use a boolean to represent them.
pub type CasReturnType {
  /// Data was stored successfully, i.e. the data was not modified since it was fetched with g(e|a)ts.
  CasStored
  /// Data was not stored, i.e. the data was modified since it was fetched with g(e|a)ts.
  /// This value is also returned if the `cas_unique` value is invalid, but the key exists.
  CasExists
  /// The key does not exist.
  CasNotFound
}

/// Sets this value only if it wasn't modified since the time it was fetched with a
/// CAS (check and store) command like gets/gats. These commands return a unique CAS
/// value, which must be passed as the `cas_unique` parameter to this function.
///
/// # Example
///
/// ```gleam
/// cas(
///   mem,
///   key: "foo",
///   flags: flag.bit_array_to_uint16(<<1234>>),
///   exptime: 100,
///   data: <<"Hi!">>,
///   cas_unique: 10
/// )
/// ```
pub fn cas(
  mem: Memcached,
  key key: String,
  flags flags: Int,
  exptime exptime: Int,
  cas_unique cas_unique: Int,
  data data: BitArray,
) -> Result(CasReturnType, MemcachedError) {
  case
    StorageCommand(
      cmd: Cas(cas_unique:),
      key:,
      flags:,
      exptime:,
      size: byte_size(data),
      data:,
    )
    |> run_text_command(mem, _, False)
  {
    Ok(res) ->
      case res {
        Stored -> Ok(CasStored)
        Exists -> Ok(CasExists)
        NotFound -> Ok(CasNotFound)
        _ -> Error(CommandError(GeneralError))
      }
    Error(e) -> Error(e)
  }
}

// Retrieval Commands

/// Gets the values and flags of these keys.
/// If a value is not found, that key will not exist in the returned list.
///
/// # Example
///
/// ```gleam
/// get(
///   mem,
///   keys: ["foo", "bar", "baz"],
/// )
/// ```
pub fn get(
  mem: Memcached,
  keys keys: List(String),
) -> Result(List(Value), MemcachedError) {
  case
    Get(keys:)
    |> run_text_command(mem, _, False)
  {
    Ok(res) ->
      case res {
        Values(vals) -> Ok(vals)
        _ -> Error(CommandError(GeneralError))
      }
    Error(e) -> Error(e)
  }
}

/// Gets the values, flags, and unique CAS values of these keys.
/// If a value is not found, that key will not exist in the returned list.
/// See the `cas` function to learn more about CAS.
///
/// # Example
///
/// ```gleam
/// gets(
///   mem,
///   keys: ["foo", "bar", "baz"],
/// )
/// ```
pub fn gets(
  mem: Memcached,
  keys keys: List(String),
) -> Result(List(ValueCas), MemcachedError) {
  case
    Gets(keys:)
    |> run_text_command(mem, _, False)
  {
    Ok(res) ->
      case res {
        ValuesCas(vals) -> Ok(vals)
        _ -> Error(CommandError(GeneralError))
      }
    Error(e) -> Error(e)
  }
}

// Other commands

/// Deletes the key.
/// Returns True if the key existed, otherwise returns False.
///
/// # Example
///
/// ```gleam
/// gets(
///   mem,
///   keys: ["foo", "bar", "baz"],
/// )
/// ```
pub fn delete(mem: Memcached, key: String) -> Result(Bool, MemcachedError) {
  case
    Delete(key:)
    |> run_text_command(mem, _, False)
  {
    Ok(res) ->
      case res {
        Deleted -> Ok(True)
        NotFound -> Ok(False)
        _ -> Error(CommandError(GeneralError))
      }
    Error(e) -> Error(e)
  }
}

/// Increments the value of the key by `value`.
/// The value is interpreted to be a **64-bit unsigned integer**, and any
/// overflows are replaced with zero by Memcached.
/// The Ok value is an Option, which will be None if `key` does not exist.
/// If `key`'s value is not an integer, a CommandError will be raised with
/// the message: `"cannot increment or decrement non-numeric value"`
///
/// # Example
///
/// ```gleam
/// incr(
///   mem,
///   key: "foo",
///   value: 1
/// )
/// ```
pub fn incr(
  mem: Memcached,
  key: String,
  value: Int,
) -> Result(Option(Int), MemcachedError) {
  case
    Incr(key:, value:)
    |> run_text_command(mem, _, False)
  {
    Ok(res) ->
      case res {
        RawValue(val) -> Ok(Some(val))
        NotFound -> Ok(None)
        _ -> Error(CommandError(GeneralError))
      }
    Error(e) -> Error(e)
  }
}

/// Decrements the value of the key by `value`.
/// The value is interpreted to be a **64-bit unsigned integer**, and any
/// underflows are replaced with zero by Memcached.
/// The Ok value is an Option, which will be None if `key` does not exist.
/// If `key`'s value is not an integer, a CommandError will be raised with
/// the message: `"cannot increment or decrement non-numeric value"`
///
/// # Example
///
/// ```gleam
/// decr(
///   mem,
///   key: "foo"
///   value: 1
/// )
/// ```
pub fn decr(
  mem: Memcached,
  key: String,
  value: Int,
) -> Result(Option(Int), MemcachedError) {
  case
    Decr(key:, value:)
    |> run_text_command(mem, _, False)
  {
    Ok(res) ->
      case res {
        RawValue(val) -> Ok(Some(val))
        NotFound -> Ok(None)
        _ -> Error(CommandError(GeneralError))
      }
    Error(e) -> Error(e)
  }
}

/// Change the expiration time of `key` to `exptime` (in seconds or unix epoch if `exptime` is
/// greater than 30 days (30 * 24 * 60 * 60 seconds)). An expiration time of 0 indicates that
/// the key never expires, and an expiration time of a negative number indicates immediate
/// expiration.
///
/// # Example
///
/// ```gleam
/// touch(
///   mem,
///   key: "foo"
///   exptime: 100
/// )
/// ```
pub fn touch(
  mem: Memcached,
  key: String,
  exptime: Int,
) -> Result(Bool, MemcachedError) {
  case
    Touch(key:, exptime:)
    |> run_text_command(mem, _, False)
  {
    Ok(res) ->
      case res {
        Touched -> Ok(True)
        NotFound -> Ok(False)
        _ -> Error(CommandError(GeneralError))
      }
    Error(e) -> Error(e)
  }
}

/// Get and Touch.
/// Change the expiration time of all `keys` to `exptime` (in seconds or unix epoch if `exptime`
/// is greater than 30 days (30 * 24 * 60 * 60 seconds)). An expiration time of 0 indicates that
/// the key never expires, and an expiration time of a negative number indicates immediate
/// expiration. Returns the values of each of the `keys` (similar to the `get` function).
/// `exptime` is specified before `keys` to mimic the equivalent Memcached command's syntax.
///
/// # Example
///
/// ```gleam
/// gat(
///   mem,
///   exptime: 100
///   keys: ["foo", "bar", "baz"]
/// )
/// ```
pub fn gat(
  mem: Memcached,
  exptime: Int,
  keys: List(String),
) -> Result(List(Value), MemcachedError) {
  case
    GetAndTouch(keys:, exptime:)
    |> run_text_command(mem, _, False)
  {
    Ok(res) ->
      case res {
        Values(val) -> Ok(val)
        _ -> Error(CommandError(GeneralError))
      }
    Error(e) -> Error(e)
  }
}

/// Get and Touch returning unique CAS values.
/// Change the expiration time of all `keys` to `exptime` (in seconds or unix epoch if `exptime`
/// is greater than 30 days (30 * 24 * 60 * 60 seconds)). An expiration time of 0 indicates that
/// the key never expires, and an expiration time of a negative number indicates immediate
/// expiration. Returns the values of each of the `keys` (similar to the `gets` command).
/// `exptime` is specified before `keys` to mimic the equivalent Memcached command's syntax.
///
/// # Example
///
/// ```gleam
/// gats(
///   mem,
///   exptime: 100
///   keys: ["foo", "bar", "baz"]
/// )
/// ```
pub fn gats(
  mem: Memcached,
  exptime: Int,
  keys: List(String),
) -> Result(List(ValueCas), MemcachedError) {
  case
    GetAndTouchs(keys:, exptime:)
    |> run_text_command(mem, _, False)
  {
    Ok(res) ->
      case res {
        ValuesCas(val) -> Ok(val)
        _ -> Error(CommandError(GeneralError))
      }
    Error(e) -> Error(e)
  }
}
