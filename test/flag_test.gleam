import gleeunit/should
import glemcached/flag

pub fn uint16_to_bitarray_test() {
  flag.uint16_to_bitarray(10)
  |> should.equal(<<0, 10>>)

  flag.uint16_to_bitarray(100_000)
  |> should.equal(<<65_535:size(16)>>)

  flag.uint16_to_bitarray(-1)
  |> should.equal(<<0:size(16)>>)
}

pub fn bitarray_to_uint16_test() {
  flag.bitarray_to_uint16(<<10>>)
  |> should.equal(10)

  flag.bitarray_to_uint16(<<65_535:size(16)>>)
  |> should.equal(65_535)

  flag.bitarray_to_uint16(<<3, 2, 1, 0>>)
  |> should.equal(0b0000001100000010)
}
