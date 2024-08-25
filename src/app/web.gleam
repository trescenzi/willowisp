import app/checker.{type CheckerActor}
import app/middleware
import gleam/otp/actor.{type StartError}
import gleam/dynamic
import gleam/result.{map_error}
import mist
import sqlight
import wisp.{type Request, type Response}
import app/routes/home.{home}
import app/routes/add.{add}

pub fn router(req: Request, ctx: middleware.Context) -> Response {
  case wisp.path_segments(req) {
    [] -> home(req, ctx)

    ["add", ..] -> add(req, ctx)

    _ -> wisp.not_found()
  }
}

pub fn handle_request(req: Request, ctx: middleware.Context) -> Response {
  middleware.middleware(req, ctx, router)
}

pub fn init(
  checker: CheckerActor,
  password: String
) {
  let assert Ok(db) = sqlight.open("./willowisp.sqlite")
  let ctx = middleware.Context(db, checker, password)
  let handler = handle_request(_, ctx)

  wisp.mist_handler(handler, password)
    |> mist.new()
    |> mist.port(8080)
    |> mist.start_http()
    |> map_error(to_starterror)
}

fn to_starterror(glisten_error) -> StartError {
  actor.InitCrashed(dynamic.from(glisten_error))
}
