import gleam/bit_array
import gleam/result
import glemcached/text.{add, set}
import glemcached/types.{
  type CommandError, type Memcached, ClientError, CommandError, Memcached,
}
import mug

// TODO: SSL
/// This record holds the options used to connect (and authenticate)
/// to the memcached instance.
pub type ConnectionOptions {
  ConnectionOptions(
    host: String,
    port: Int,
    timeout: Int,
    username: String,
    password: String,
  )
}

/// Create a new `ConnectionOptions`
pub fn new(host, port) {
  ConnectionOptions(host, port, 1000, "", "")
}

/// Set the `ConnectionOptions`' timeout value
pub fn with_timeout(conn, timeout timeout) {
  ConnectionOptions(..conn, timeout:)
}

/// Set the username and password fields of `ConnectionOptions`
pub fn with_authentication(conn, username username, password password) {
  // FIXME: Tree sitter gets confused if the `username` label
  // is provided as a shorthand, hence it's put in the long
  // form here until tree-sitter is fixed.
  ConnectionOptions(..conn, username: username, password:)
}

/// Error returned while connecting to the Memcached instance
pub type ConnectionError {
  /// Something went wrong trying to establish a connection
  ConnectError(mug.Error)
  /// The (maybe) provided credentials are wrong
  AuthenticationFailure
}

/// Check if authentication is required. This sends the ADD
/// text command with the key auth, and an expiration time of
/// -1, so that, when authentication is not required:
///  - if the key `auth` already exists, it remains unchanged
///  - if the key `auth` does not exist, it is added and
///    immediately removed.
fn check_auth(mem: Memcached) -> Result(Bool, ConnectionError) {
  case add(mem, "auth", 0, -1, <<1>>) {
    Error(CommandError(ClientError(error))) ->
      case error {
        "unauthenticated\r\n" -> Ok(True)
        _ -> Ok(False)
      }
    _ -> Ok(False)
  }
}

/// Authenticate the request. This function must be called only if
/// authentication is required, otherwise the key `auth` (if present)
/// will be overwritten (and deleted).
fn authenticate(mem: Memcached, user: String, pass: String) -> Bool {
  let data = user <> " " <> pass
  case set(mem, "auth", 0, 0, bit_array.from_string(data)) {
    Ok(_) -> True
    _ -> False
  }
}

/// Connect to a Memcached instance. This function creates a new TCP
/// connection to host:port using mug. The connection times out after
/// `timeout` millis.
///
/// The returned Result has an Ok value of `Memcached`, which holds the
/// connection socket and the command timeout value (default `timeout`),
/// which can be changed with the `with_timeout` function. The Error
/// value of the result is the mug.Error returned while creating the
/// connection or checking for authentication.
///
/// To check for authentication, the client sends an empty request to
/// the instance, which will respond with `CLIENT_ERROR unauthorized`
/// if authentication is required. Then, the client will send the
/// credentials using a SET command. It sets the key `auth` with an
/// expiration of `-1`.
///
/// # Example
///
/// ```gleam
/// let mem = new(host, port)
/// |> with_timeout(500)
/// |> with_authentication("user", "pass")
/// |> connect()
/// ```
pub fn connect(opts: ConnectionOptions) -> Result(Memcached, ConnectionError) {
  let ConnectionOptions(host, port, timeout, username, password) = opts
  let assert Ok(socket) =
    mug.new(host, port)
    |> mug.timeout(timeout)
    |> mug.connect()

  let mem = Memcached(socket, timeout)
  use auth_required <- result.try(check_auth(mem))
  case auth_required {
    True -> {
      case authenticate(mem, username, password) {
        True -> Ok(mem)
        False -> Error(AuthenticationFailure)
      }
    }
    _ -> Ok(mem)
  }
}

/// Close the connection
pub fn close(mem: Memcached) -> Result(Nil, mug.Error) {
  mug.shutdown(mem.socket)
}
