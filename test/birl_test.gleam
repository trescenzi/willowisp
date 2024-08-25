import gleeunit
import gleeunit/should
import birl

pub fn main() {
  gleeunit.main()
}

pub fn birl_parse_test() {
  let assert Ok(time) = birl.from_naive("2024-08-24T01:49:44")
  time
  |> birl.get_day
  |> should.equal(birl.Day(2024, 08, 24))
}
