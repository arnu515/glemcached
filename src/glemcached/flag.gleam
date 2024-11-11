import gleam/int

pub fn bitarray_to_uint16(ba: BitArray) -> Int {
  case ba {
    <<>> -> 0
    <<a>> -> a
    <<a, b, _:bits>> -> int.bitwise_shift_left(a, 8) + b

    // unreachable
    _ -> 0
  }
}

pub fn uint16_to_bitarray(num: Int) -> BitArray {
  <<int.clamp(num, 0, 65_535):size(16)>>
}
