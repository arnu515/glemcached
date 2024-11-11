[![Package Version](https://img.shields.io/hexpm/v/glemcached)](https://hex.pm/packages/glemcached)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/glemcached/)

# glemcached

[Memcached](https://memcached.org) client in pure gleam! (except the TCP client, of course! That's [mug](https://github.com/lpil/mug)).

Made with the goal of fully supporting the [Memcached protocol](https://github.com/memcached/memcached/blob/master/doc/protocol.txt)!

## Features

(help wanted!)

- [X] Authentication
- [X] Text Commands
- [ ] SSL
- [ ] Meta Commands
- [ ] Connection pooling
- [ ] Cluster support
- [ ] First class actor support
- [ ] JavaScript (!Browser) support with promises

Binary commands are deprecated and hence will not be implemented.

## Install

```sh
gleam add glemcached
```

## Example with text commands
```gleam
import gleam/bit_array
import gleam/io
import glemcached.{connect, with_authentication, with_timeout}
import glemcached/text

pub fn main() {
  let assert Ok(mem) =
    glemcached.new("localhost", 11_211)
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
```

Further documentation can be found at <https://hexdocs.pm/glemcached>.

## Development

```sh
gleam run -m glemcached/examples/text # Run the example
gleam test  # Run the tests
```
