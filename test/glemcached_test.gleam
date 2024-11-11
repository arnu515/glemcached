import gleam/io
import gleeunit
import gleeunit/should
import glemcached
import glemcached/internal/text.{Value} as _
import glemcached/text

pub fn main() {
  gleeunit.main()
}

pub fn auth_test() {
  glemcached.new("localhost", 11_212)
  |> glemcached.with_authentication("user", "pass")
  |> glemcached.connect()
  |> should.be_ok()

  glemcached.new("localhost", 11_212)
  |> glemcached.connect()
  |> should.be_error()
  |> should.equal(glemcached.AuthenticationFailure)
}

// gleeunit test functions end in `_test`
pub fn commands_test() {
  let assert Ok(mem) =
    glemcached.new("localhost", 11_211)
    |> glemcached.connect()

  io.println("1")
  text.set(mem, "foo", 0, 0, <<"1">>)
  |> should.be_ok()
  |> should.equal(Nil)

  io.println("2")
  text.get(mem, ["foo", "bar"])
  |> should.be_ok()
  |> should.equal([Value(key: "foo", flags: 0, data: <<"1">>)])

  io.println("3")
  text.add(mem, "foo", 0, 0, <<"2">>)
  |> should.be_ok()
  |> should.equal(False)

  io.println("4")
  text.add(mem, "bar", 0, 0, <<"1">>)
  |> should.be_ok()
  |> should.equal(True)

  io.println("5")
  text.delete(mem, "bar")
  |> should.be_ok()
  |> should.equal(True)

  io.println("6")
  text.delete(mem, "bar")
  |> should.be_ok()
  |> should.equal(False)

  io.println("7")
  text.replace(mem, "foo", 0, 0, <<"2">>)
  |> should.be_ok()
  |> should.equal(True)

  io.println("8")
  text.replace(mem, "bar", 0, 0, <<"1">>)
  |> should.be_ok()
  |> should.equal(False)

  io.println("9")
  text.get(mem, ["foo"])
  |> should.be_ok()
  |> should.equal([Value(key: "foo", flags: 0, data: <<"2">>)])

  io.println("10")
  text.incr(mem, "foo", 1)
  |> should.be_ok()
  |> should.be_some()
  |> should.equal(3)

  io.println("11")
  text.get(mem, ["bar"])
  |> should.be_ok()
  |> should.equal([])

  io.println("12")
  text.decr(mem, "foo", 1)
  |> should.be_ok()
  |> should.be_some()
  |> should.equal(2)

  io.println("13")
  text.touch(mem, "foo", 10)
  |> should.be_ok()
  |> should.equal(True)

  io.println("14")
  text.gat(mem, -1, ["foo"])
  |> should.be_ok()
  |> should.equal([Value("foo", 0, <<"2">>)])

  io.println("15")
  text.touch(mem, "foo", -1)
  |> should.be_ok()
  |> should.equal(False)
}

pub fn cas_commands_test() {
  let assert Ok(mem) =
    glemcached.new("localhost", 11_211)
    |> glemcached.connect()

  text.set(mem, "foo", 0, 0, <<"1">>)
  |> should.be_ok()
  |> should.equal(Nil)

  let assert [value] =
    text.gets(mem, ["foo", "bar"])
    |> should.be_ok()

  text.cas(mem, value.key, value.flags, 0, value.cas_unique, value.data)
  |> should.be_ok()
  |> should.equal(text.CasStored)

  let assert [value] =
    text.gets(mem, ["foo"])
    |> should.be_ok()

  text.set(mem, "foo", 0, 0, <<"1">>)
  |> should.be_ok()
  |> should.equal(Nil)

  text.cas(mem, value.key, value.flags, 0, value.cas_unique, value.data)
  |> should.be_ok()
  |> should.equal(text.CasExists)

  let assert [value] =
    text.gats(mem, -1, ["foo"])
    |> should.be_ok()

  text.cas(mem, value.key, value.flags, 0, value.cas_unique, value.data)
  |> should.be_ok()
  |> should.equal(text.CasNotFound)
}
