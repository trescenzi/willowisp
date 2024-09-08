import birl
import birl/duration
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn birl_parse_test() {
  let assert Ok(time) = birl.from_naive("2024-08-24T01:49:44")
  time
  |> birl.get_day
  |> should.equal(birl.Day(2024, 08, 24))
}

pub fn birl_expiry_test() {
  let distance = duration.seconds(604_800 - 1000)
  let assert Ok(now) = birl.parse("2024-08-28T22:49:16.034Z")
  birl.add(now, distance)
  |> birl.to_iso8601()
  |> should.equal("2024-09-04T22:32:36.034Z")
}
