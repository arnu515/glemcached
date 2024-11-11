//// Example for using Memcached text commands!
//// Ensure a Memcached server with the authentication credentials of
//// `user:pass` is listening on port `11211` by running:
//// ```shell
//// cat "user:pass" | memcached -p 11211 -Y /dev/stdin
//// ```
//// And then run this file using `gleam run -m examples/text`

import gleam/bit_array
import gleam/io
import glemcached.{connect, new, with_authentication, with_timeout}
import glemcached/text

pub fn main() {
  let assert Ok(mem) =
    new("localhost", 11_211)
    |> with_timeout(500)
    |> with_authentication("user", "pass")
    |> connect()

  let assert Ok(Nil) = text.set(mem, "foo", 123, 0, <<"Hello">>)
  let assert Ok(True) = text.append(mem, "foo", 123, 0, <<", world!">>)
  let assert Ok([value]) = text.get(mem, ["foo"])
  let assert Ok(value) = bit_array.to_string(value.data)

  // clean up!
  let assert Ok(True) = text.delete(mem, "foo")

  io.println(value)
}
