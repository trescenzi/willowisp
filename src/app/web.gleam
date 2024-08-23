import app/checker.{type CheckerActor}
import app/middleware
import gleam/otp/actor.{type StartError}
import gleam/dynamic
import gleam/result.{map_error}
import mist
import sqlight
import wisp.{type Request, type Response}
import app/routes/home.{home}

pub fn handle_request(req: Request, ctx: middleware.Context) -> Response {
  //use req, ctx <- middleware.wrap_base(req, ctx)

  case wisp.path_segments(req) {
    [] -> home(req, ctx)

    ["art", ..] -> wisp.not_found()
    ["blog", ..] -> wisp.not_found()
    ["comics", ..] -> wisp.not_found()
    ["links", ..] -> wisp.not_found()

    _ -> wisp.not_found()
  }
}

pub fn init(
  checker: CheckerActor,
) {
  let assert Ok(db) = sqlight.open("./willowisp.sqlite")
  let ctx = middleware.Context(db, checker)
  let handler = handle_request(_, ctx)

  wisp.mist_handler(handler, "kjdfnakjdnfakjsdnf1")
    |> mist.new()
    |> mist.port(8080)
    |> mist.start_http()
    |> map_error(to_starterror)
}

fn to_starterror(glisten_error) -> StartError {
  actor.InitCrashed(dynamic.from(glisten_error))
}
