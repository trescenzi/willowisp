import app/discord/channel.{create_bot_dm_channel, send_bot_message_to_channel}
import app/middleware
import app/views/layout.{layout}
import gleam/http.{Get}
import gleam/io
import gleam/result
import lustre/element.{to_document_string_builder}
import lustre/element/html.{text}
import wisp.{type Request, type Response}

pub fn send_message_test(
  req: Request,
  _ctx: middleware.Context,
  id: String,
) -> Response {
  case req.method {
    Get -> {
      case send_message(id) {
        Ok(res) -> res
        Error(e) -> {
          io.debug(e)
          wisp.bad_request()
        }
      }
    }
    _ -> wisp.method_not_allowed(allowed: [Get])
  }
}

fn send_message(id: String) {
  io.debug(id)

  use channel <- result.try(create_bot_dm_channel(id))
  let res = send_bot_message_to_channel("hello world", channel:)
  let _ = io.debug(res)

  Ok(
    layout([text("hello world")])
    |> to_document_string_builder
    |> wisp.html_response(200),
  )
}
