import app/helpers.{bearer_auth}
import birl
import gleam/dynamic
import gleam/hackney
import gleam/http.{Get}
import gleam/http/request
import gleam/int
import gleam/io
import gleam/json.{decode}
import gleam/list
import gleam/result
import sqlight

pub type UserError {
  BadRequest
  BadResponse
  BadToken
  TokenSelection
  ExpiredToken(String)
}

pub fn me(access_token: String) {
  use response <- result.try(
    request.new()
    |> request.set_method(Get)
    |> request.set_host("discord.com")
    |> request.set_path("/api/v10/users/@me")
    |> request.set_header("accept", "application/json")
    |> bearer_auth(access_token)
    |> io.debug
    |> hackney.send
    |> result.replace_error(BadRequest),
  )

  io.debug(response.body)

  decode_user(response.body)
  |> result.replace_error(BadResponse)
}

pub type DiscordUser {
  DiscordUser(id: String, username: String)
}

pub fn decode_user(user_json: String) {
  decode(
    user_json,
    dynamic.decode2(
      DiscordUser,
      dynamic.field("id", of: dynamic.string),
      dynamic.field("username", of: dynamic.string),
    ),
  )
}

//fn save_access_token(user_id user_id: String, access_token refresh_token: String, expiry expiry: String, db db: sqlight.Connection) {
//let sql = "update discord_users set access_token = % and expiry = % where id = %"
//}

pub fn get_token(user_id: String, db: sqlight.Connection) {
  let sql =
    "
    select  unixepoch(expiry), access_token, refresh_token from discord_users where id = ?;
  "
  let query_type = dynamic.tuple3(dynamic.int, dynamic.string, dynamic.string)
  use user_id <- result.try(
    int.parse(user_id) |> result.replace_error(TokenSelection),
  )
  io.debug(user_id)
  use response <- result.try(
    sqlight.query(
      sql,
      on: db,
      with: [sqlight.int(user_id)],
      expecting: query_type,
    )
    |> result.map_error(fn(e) { io.debug(e) })
    |> result.replace_error(TokenSelection),
  )
  io.debug(response)
  use response <- result.try(
    list.first(response)
    |> result.replace_error(TokenSelection),
  )
  let now = birl.to_unix(birl.now())
  let expired = now > response.0
  io.debug(expired)
  io.debug(response)
  case expired {
    True -> Error(ExpiredToken(response.2))
    False -> Ok(response.1)
  }
}
