import mug.{type Socket}

/// A record that holds the TCP socket between the client
/// and the memcached instance, and also holds the timeout
/// value which can be changed if desired. It defaults to
/// whatever value was set with `with_timeout`, or 1000, if
/// `with_timeout` wasn't called.
pub type Memcached {
  Memcached(socket: Socket, timeout: Int)
}

/// General Error type for all errors returned by
/// this library.
pub type MemcachedError {
  /// Something happened while trying to use the TCP socket
  SocketError(mug.Error)
  /// The memcached command failed to execute
  CommandError(CommandError)
  /// The data returned by memcached wasn't able to be parsed.
  /// This error is usually NEVER raised, and if it is raised, which
  /// means that there is a bug in the protocol implementation in
  /// either this libarary or the Memcached instance.
  /// (Usually it's the former, so any bug reports are highly appreciated!)
  ParseError(ParseError)
}

/// Memcached returns three types of errors:
/// ERROR -> invalid command
/// CLIENT_ERROR <error>-> some error in the usage of a command.
///   <error> is a human readable string
/// SERVER_ERROR <error>-> some error in the execution of a command.
///   <error> is a human readable string
pub type CommandError {
  GeneralError
  ClientError(String)
  ServerError(String)
}

/// ParseError is returned when there is an error in parsing the 
/// response returned by the Memcached server. If this error is
/// returned, there either exists a bug in this libarary, or in the
/// Memcached instance's implementation. This library is tested on
/// the official Memcached instance, therefore, if you're using this
/// library with the official instance, and a ParseError is raised,
/// there is definitely a bug with the library. Please report it <3
pub type ParseError {
  /// When the response starts with an unexpected keyword
  InvalidResponse
  /// When there's an error trying to parse VALUE ...
  ValueParseError
}
