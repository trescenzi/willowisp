import app/checker.{type CheckerActor}
import app/db.{get_connection}
import app/middleware
import app/routes/add.{add}
import app/routes/home.{home}
import app/routes/oauth.{oauth}
import app/routes/save_notifications.{save_notifications}
import app/routes/send_message_test.{send_message_test}
import gleam/dynamic
import gleam/io
import gleam/list
import gleam/otp/actor.{type StartError}
import gleam/result.{map_error}
import mist
import wisp.{type Request, type Response}

pub fn router(req: Request, ctx: middleware.Context) -> Response {
  wisp.path_segments(req)
  |> list.map(io.debug)
  wisp.get_query(req)
  |> list.map(io.debug)
  case wisp.path_segments(req) {
    [] -> home(req, ctx)

    ["add", ..] -> add(req, ctx)
    ["oauth", ..] -> oauth(req, ctx)
    ["save_notifications", ..] -> save_notifications(req, ctx)
    ["send_message", id] -> send_message_test(req, ctx, id)

    _ -> wisp.not_found()
  }
}

pub fn handle_request(req: Request, ctx: middleware.Context) -> Response {
  middleware.middleware(req, ctx, router)
}

pub fn init(checker: CheckerActor, password: String) {
  let assert Ok(db) = get_connection()
  let ctx = middleware.Context(db, checker, password)
  let handler = handle_request(_, ctx)

  wisp.mist_handler(handler, password)
  |> mist.new()
  |> mist.port(8081)
  |> mist.start_http()
  |> map_error(to_starterror)
}

fn to_starterror(glisten_error) -> StartError {
  actor.InitCrashed(dynamic.from(glisten_error))
}
