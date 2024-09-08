import app/helpers.{basic_auth}
import gleam/dynamic
import gleam/hackney
import gleam/http.{Post}
import gleam/http/request
import gleam/io
import gleam/json.{decode}
import gleam/result.{replace_error}
import gleam/uri

pub type AuthResponse {
  AuthResponse(
    access_token: String,
    id_token: String,
    refresh_token: String,
    expires_in: Int,
  )
}

pub fn decode_auth_code(auth_json) {
  decode(
    auth_json,
    dynamic.decode4(
      AuthResponse,
      dynamic.field("access_token", of: dynamic.string),
      dynamic.field("id_token", of: dynamic.string),
      dynamic.field("refresh_token", of: dynamic.string),
      dynamic.field("expires_in", of: dynamic.int),
    ),
  )
}

pub type OAuthError {
  RequestError
}

pub fn auth_code_request(code: String) {
  let body = {
    let list = [
      #("code", code),
      #("grant_type", "authorization_code"),
      #("redirect_uri", "http://localhost:8081/oauth"),
    ]
    uri.query_to_string(list)
  }

  request.new()
  |> request.set_method(Post)
  |> request.set_host("discord.com")
  |> request.set_path("/api/v10/oauth2/token")
  |> request.set_header("accept", "application/json")
  |> request.set_header("content-type", "application/x-www-form-urlencoded")
  |> basic_auth("1277745653312651317", "FwKC1QgoVmz7pXz6NTmCKoV4HQYM8n5g")
  |> request.set_body(body)
  |> io.debug
  |> hackney.send
  //|> replace_error(RequestError)
}

pub fn refresh_token(token: String) {
  let body = {
    let list = [
      #("refresh_token", token),
      #("grant_type", "refresh_token"),
      #("redirect_uri", "http://localhost:8081/oauth"),
    ]
    uri.query_to_string(list)
  }

  request.new()
  |> request.set_method(Post)
  |> request.set_host("discord.com")
  |> request.set_path("/api/v10/oauth2/token")
  |> request.set_header("accept", "application/json")
  |> request.set_header("content-type", "application/x-www-form-urlencoded")
  |> basic_auth("1277745653312651317", "FwKC1QgoVmz7pXz6NTmCKoV4HQYM8n5g")
  |> request.set_body(body)
  |> io.debug
  |> hackney.send
  //|> replace_error(RequestError)
}
