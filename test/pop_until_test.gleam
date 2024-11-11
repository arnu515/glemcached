import gleeunit/should
import glemcached/internal/pop_ba.{pop_until_rn, pop_until_space_on_same_line}

pub fn pop_until_space_on_same_line_test() {
  pop_until_space_on_same_line(<<"ABC DEF">>)
  |> should.be_some
  |> should.equal(#(<<"ABC">>, <<"DEF">>))

  pop_until_space_on_same_line(<<" ABC">>)
  |> should.be_some
  |> should.equal(#(<<>>, <<"ABC">>))

  pop_until_space_on_same_line(<<"ABC ">>)
  |> should.be_some
  |> should.equal(#(<<"ABC">>, <<>>))

  pop_until_space_on_same_line(<<"ABC DEF GHI">>)
  |> should.be_some
  |> should.equal(#(<<"ABC">>, <<"DEF GHI">>))

  pop_until_space_on_same_line(<<"ABCDEF">>)
  |> should.be_none

  pop_until_space_on_same_line(<<"ABC DEF\r\nGHI">>)
  |> should.be_some
  |> should.equal(#(<<"ABC">>, <<"DEF\r\nGHI">>))

  pop_until_space_on_same_line(<<"\r\nABC DEF">>)
  |> should.be_none
}

pub fn pop_until_rn_test() {
  pop_until_rn(<<"ABC\r\nDEF">>)
  |> should.be_some
  |> should.equal(#(<<"ABC">>, <<"DEF">>))

  pop_until_rn(<<"\r\nABC">>)
  |> should.be_some
  |> should.equal(#(<<>>, <<"ABC">>))

  pop_until_rn(<<"ABC\r\n">>)
  |> should.be_some
  |> should.equal(#(<<"ABC">>, <<>>))

  pop_until_rn(<<"ABC\r\nDEF\r\nGHI">>)
  |> should.be_some
  |> should.equal(#(<<"ABC">>, <<"DEF\r\nGHI">>))

  pop_until_rn(<<"ABCDEF">>)
  |> should.be_none
}
