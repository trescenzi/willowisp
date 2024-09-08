import app/helpers.{bot_auth, set_body_json}
import gleam/dynamic
import gleam/erlang/os.{get_env}
import gleam/hackney
import gleam/http.{Post}
import gleam/http/request
import gleam/io
import gleam/json.{decode}
import gleam/result

pub type DiscordChannel {
  DiscordDMChannel(id: String)
}

pub type ChannelError {
  BadResponse
  BadRequest
}

pub fn decode_dm_channel(dm_json: String) {
  decode(
    dm_json,
    dynamic.decode1(DiscordDMChannel, dynamic.field("id", of: dynamic.string)),
  )
}

pub fn create_bot_dm_channel(recipient_id id: String) {
  let assert Ok(bot_token) = get_env("WILLOWISP_BOT_TOKEN")
  create_dm_channel(sender_token: bot_token, recipient_id: id)
}

pub fn create_dm_channel(
  sender_token access_token: String,
  recipient_id id: String,
) {
  let body = {
    let object = [#("recipient_id", json.string(id))]
    json.object(object)
  }

  use response <- result.try(
    request.new()
    |> request.set_method(Post)
    |> request.set_host("discord.com")
    |> request.set_path("/api/v10/users/@me/channels")
    |> request.set_header("accept", "application/json")
    |> set_body_json(body)
    // TODO make bearer an option
    |> bot_auth(access_token)
    |> io.debug
    |> hackney.send
    |> result.replace_error(BadRequest),
  )

  io.debug(response.body)

  decode_dm_channel(response.body)
  |> result.replace_error(BadResponse)
}

pub fn send_bot_message_to_channel(
  message message: String,
  channel channel_id: DiscordChannel,
) {
  let assert Ok(bot_token) = get_env("WILLOWISP_BOT_TOKEN")
  send_message_to_channel(
    message:,
    channel: channel_id,
    access_token: bot_token,
  )
}

pub fn send_message_to_channel(
  message message: String,
  channel channel_id: DiscordChannel,
  access_token access_token: String,
) {
  let body = {
    let object = [#("content", json.string(message))]
    json.object(object)
  }
  let channel_id = case channel_id {
    DiscordDMChannel(id) -> id
  }
  use response <- result.try(
    request.new()
    |> request.set_method(Post)
    |> request.set_host("discord.com")
    |> request.set_path("/api/v10/channels/" <> channel_id <> "/messages")
    |> request.set_header("accept", "application/json")
    |> set_body_json(body)
    // TODO make bearer an option
    |> bot_auth(access_token)
    |> io.debug
    |> hackney.send
    |> result.replace_error(BadRequest),
  )

  io.debug(response.body)

  decode_dm_channel(response.body)
  |> result.replace_error(BadResponse)
}
