import gleam/bit_array
import gleam/http/request.{type Request}
import gleam/json.{type Json, decode}

pub fn basic_auth(
  request: Request(b),
  user user: String,
  password password: String,
) -> Request(b) {
  let encoded =
    bit_array.from_string(user <> ":" <> password)
    |> bit_array.base64_encode(True)

  request.set_header(request, "Authorization", "Basic " <> encoded)
}

pub fn bearer_auth(request: Request(b), auth_token: String) -> Request(b) {
  request.set_header(request, "Authorization", "Bearer " <> auth_token)
}

pub fn bot_auth(request: Request(b), auth_token: String) -> Request(b) {
  request.set_header(request, "Authorization", "Bot " <> auth_token)
}

pub fn set_body_json(request: Request(b), body body: Json) -> Request(String) {
  request
  |> request.set_body(json.to_string(body))
  |> request.set_header("content-type", "application/json")
}
