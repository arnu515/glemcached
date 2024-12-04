//// !!!!!!!!
//// Internal API -- May change at any time
//// NOT COVERED BY SEMVER!!!
//// !!!!!!!!

import gleam/bit_array
import gleam/bytes_builder.{
  type BytesBuilder, append, from_string_builder as from_sb,
}
import gleam/int
import gleam/option
import gleam/result.{unwrap}
import gleam/string
import gleam/string_builder as sb
import glemcached/internal/pop_ba.{pop_until_rn, pop_until_space_on_same_line}
import glemcached/types.{
  type Memcached, type MemcachedError, ClientError, CommandError, GeneralError,
  InvalidResponse, ParseError, ServerError, SocketError, ValueParseError,
}
import mug

/// Internal representation for sending text commands to
/// Memcached. These are built off of their definitions
/// in [protocol.txt](https://github.com/memcached/memcached/blob/master/doc/protocol.txt).
///
/// Some useful information is given below:
///
/// cmd -> name of the command
/// key -> key the command operates on
/// flags -> a 16-bit integer that is stored with the key
/// exptime -> either a unix timestamp (time when key expires), or
///   the number of seconds from now() for the key to expire. If
///   zero, the key never expires (unless it gets cleaned by the
///   LRU cache). If negative, key immediately expires.
/// data -> the data to be set
/// cas_unique -> the unique 64-bit value returned by `gets`
/// 
/// keys -> All the keys to get
///
/// TODO: Add this to INCR/DECR commands
/// NOTE with incr, decr: They treat the number like a 64 bit unsigned integer
pub type TextCommand {
  // Storage commands
  StorageCommand(
    cmd: StorageCommand,
    key: String,
    flags: Int,
    exptime: Int,
    size: Int,
    data: BitArray,
  )

  // Retrieval commands
  Get(keys: List(String))
  Gets(keys: List(String))

  // Delete command
  Delete(key: String)

  // Increment/Decrement command
  Incr(key: String, value: Int)
  Decr(key: String, value: Int)

  // Touch command
  Touch(key: String, exptime: Int)
  GetAndTouch(exptime: Int, keys: List(String))
  GetAndTouchs(exptime: Int, keys: List(String))
}

// set, add, replace, append, prepend
pub type StorageCommand {
  Set
  Add
  Replace
  Append
  Prepend
  // cas_unique -> 64-bit value
  Cas(cas_unique: Int)
}

/// Response returned by Memcached on running text commands.
pub type TextResponse {
  /// Item stored successfully
  Stored
  /// The condition for an add or replace command was not met
  NotStored
  /// CAS item was modified since last fetched
  Exists

  // Retrieval responses
  Values(List(Value))
  ValuesCas(List(ValueCas))

  /// Item deleted successfully
  Deleted

  // Incr/Decr responses
  RawValue(Int)

  // Touch responses
  Touched

  /// The item does not exist
  NotFound

  /// For internal use (returned when using noreply)
  Blank
}

pub type Value {
  Value(key: String, flags: Int, data: BitArray)
}

pub type ValueCas {
  ValueCas(key: String, flags: Int, data: BitArray, cas_unique: Int)
}

fn storage_cmd_to_string(cmd: StorageCommand) {
  case cmd {
    Set -> "set"
    Add -> "add"
    Replace -> "replace"
    Append -> "append"
    Prepend -> "prepend"
    Cas(_) -> "cas"
  }
}

fn add_no_reply_to_sb(sb: sb.StringBuilder, no_reply: Bool) -> sb.StringBuilder {
  case no_reply {
    True -> sb.append(sb, " noreply")
    False -> sb
  }
}

fn convert_text_command_to_bb(cmd: TextCommand, no_reply: Bool) -> BytesBuilder {
  case cmd {
    StorageCommand(cmd, key, flags, exptime, size, data) ->
      storage_cmd_to_string(cmd)
      |> sb.from_string()
      |> sb.append(string.join(
        [
          // add a space after the command
          "",
          key,
          // ensure uint16
          int.to_string(int.clamp(flags, 0, 65_535)),
          int.to_string(exptime),
        ],
        " ",
      ))
      |> sb.append(" " <> int.to_string(size))
      |> sb.append(case cmd {
        Cas(cas) -> " " <> int.to_string(cas)
        _ -> ""
      })
      |> add_no_reply_to_sb(no_reply)
      |> sb.append("\r\n")
      |> from_sb()
      |> append(data)
      |> append(<<"\r\n">>)

    Get(keys) | Gets(keys) ->
      sb.from_string(case cmd {
        Get(_) -> "get "
        Gets(_) -> "gets "
        _ -> panic as "unreachable"
      })
      |> sb.append(string.join(keys, " "))
      |> sb.append("\r\n")
      |> from_sb()

    Delete(key) ->
      sb.from_string("delete " <> key)
      |> add_no_reply_to_sb(no_reply)
      |> sb.append("\r\n")
      |> from_sb()

    Incr(key, value) | Decr(key, value) ->
      sb.from_string(case cmd {
        Incr(..) -> "incr "
        Decr(..) -> "decr "
        _ -> panic as "unreachable"
      })
      |> sb.append(key <> " " <> int.to_string(value))
      |> add_no_reply_to_sb(no_reply)
      |> sb.append("\r\n")
      |> from_sb()

    Touch(key, exptime) ->
      sb.from_string("touch " <> key <> " " <> int.to_string(exptime))
      |> add_no_reply_to_sb(no_reply)
      |> sb.append("\r\n")
      |> from_sb()

    GetAndTouch(exptime, keys) | GetAndTouchs(exptime, keys) ->
      sb.from_string(case cmd {
        GetAndTouch(..) -> "gat "
        GetAndTouchs(..) -> "gats "
        _ -> panic as "unreachable"
      })
      |> sb.append(int.to_string(exptime) <> " ")
      |> sb.append(string.join(keys, " "))
      |> sb.append("\r\n")
      |> from_sb()
  }
}

/// TODO: Find a better way to do this
fn parse_values(
  ba: BitArray,
  init: List(Value),
) -> Result(List(Value), MemcachedError) {
  case ba {
    <<"END\r\n">> -> Ok(init)
    <<"VALUE ", rest:bits>> ->
      option.unwrap(
        {
          use #(key, rest) <- option.then(pop_until_space_on_same_line(rest))
          use #(flags, rest) <- option.then(pop_until_space_on_same_line(rest))
          // clamped just in case :)
          let flags =
            int.clamp(
              result.unwrap(
                int.parse(result.unwrap(bit_array.to_string(flags), "0")),
                0,
              ),
              0,
              65_535,
            )
          use #(len, rest) <- option.then(pop_until_rn(rest))
          use len <- option.map(
            bit_array.to_string(len)
            |> result.try(int.parse)
            |> option.from_result,
          )
          let len = len * 8
          case rest {
            <<data:size(len)-bits, "\r\n", rest:bits>> -> {
              case bit_array.to_string(key) {
                Ok(key) -> {
                  let v = Value(key, flags, data)
                  parse_values(rest, [v, ..init])
                }
                _ -> Error(ParseError(ValueParseError))
              }
            }
            _ -> Error(ParseError(ValueParseError))
          }
        },
        Error(ParseError(ValueParseError)),
      )
    _ -> Error(ParseError(InvalidResponse))
  }
}

// aaaa so much repeated code!!!
fn parse_values_cas(
  ba: BitArray,
  init: List(ValueCas),
) -> Result(List(ValueCas), MemcachedError) {
  case ba {
    <<"END\r\n">> -> Ok(init)
    <<"VALUE ", rest:bits>> ->
      option.unwrap(
        {
          use #(key, rest) <- option.then(pop_until_space_on_same_line(rest))
          use #(flags, rest) <- option.then(pop_until_space_on_same_line(rest))
          // clamped just in case :)
          let flags =
            int.clamp(
              result.unwrap(
                int.parse(result.unwrap(bit_array.to_string(flags), "0")),
                0,
              ),
              0,
              65_535,
            )
          use #(len, rest) <- option.then(pop_until_space_on_same_line(rest))
          use len <- option.then(
            bit_array.to_string(len)
            |> result.try(int.parse)
            |> option.from_result,
          )
          let len = len * 8
          use #(cas, rest) <- option.then(pop_until_rn(rest))
          use cas <- option.map(
            bit_array.to_string(cas)
            |> result.try(int.parse)
            |> option.from_result,
          )
          case rest {
            <<data:size(len)-bits, "\r\n", rest:bits>> -> {
              case bit_array.to_string(key) {
                Ok(key) -> {
                  let v = ValueCas(key, flags, data, cas_unique: cas)
                  parse_values_cas(rest, [v, ..init])
                }
                _ -> Error(ParseError(ValueParseError))
              }
            }
            _ -> Error(ParseError(ValueParseError))
          }
        },
        Error(ParseError(ValueParseError)),
      )
    _ -> Error(ParseError(InvalidResponse))
  }
}

fn handle_response(mem: Memcached) -> Result(TextResponse, MemcachedError) {
  let res = mug.receive(mem.socket, mem.timeout)

  case res {
    Ok(val) ->
      case val {
        <<"STORED\r\n">> -> Ok(Stored)
        <<"NOT_STORED\r\n">> -> Ok(NotStored)
        <<"EXISTS\r\n">> -> Ok(Exists)

        <<"VALUE ", _:bits>> | <<"END\r\n">> ->
          case parse_values(val, []) {
            Ok(v) -> Ok(Values(v))
            Error(_) ->
              case parse_values_cas(val, []) {
                Ok(v) -> Ok(ValuesCas(v))
                Error(e) -> Error(e)
              }
          }

        <<"DELETED\r\n">> -> Ok(Deleted)

        <<"TOUCHED\r\n">> -> Ok(Touched)

        <<"NOT_FOUND\r\n">> -> Ok(NotFound)

        <<"ERROR">> -> Error(CommandError(GeneralError))
        <<"CLIENT_ERROR ", error:bits>> ->
          Error(
            CommandError(
              ClientError(unwrap(bit_array.to_string(error), "Unknown error")),
            ),
          )
        <<"SERVER_ERROR ", error:bits>> ->
          Error(
            CommandError(
              ServerError(unwrap(bit_array.to_string(error), "Unknown error")),
            ),
          )

        _ ->
          case
            pop_until_rn(val)
            // "to handle VALUE\r\n"
            |> option.unwrap(#(<<>>, <<>>))
            // default value (which fails int.parse).
            |> fn(x) { x.0 }
            |> bit_array.to_string
            |> result.try(int.parse)
          {
            // Incr and Decr response (technically a 64-bit number, but that is not checked)
            Ok(val) -> Ok(RawValue(val))
            Error(_) -> Error(ParseError(InvalidResponse))
          }
      }
    Error(e) -> Error(SocketError(e))
  }
}

pub fn run_text_command(
  mem: Memcached,
  cmd: TextCommand,
  no_reply: Bool,
) -> Result(TextResponse, MemcachedError) {
  let assert Ok(_) =
    convert_text_command_to_bb(cmd, no_reply)
    |> mug.send_builder(mem.socket, _)

  case no_reply {
    False -> handle_response(mem)
    True -> Ok(Blank)
  }
}
