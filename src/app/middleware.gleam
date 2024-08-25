import sqlight.{type Connection}
import app/checker.{type CheckerActor}
import wisp

pub type Context {
  Context(db: Connection, checker: CheckerActor, password: String)
}

pub fn middleware(
  req: wisp.Request,
  ctx: Context,
  handle_request: fn(wisp.Request, Context) -> wisp.Response,
) -> wisp.Response {
  let req = wisp.method_override(req)
  let assert Ok(priv_dir) = wisp.priv_directory("willowisp")
  use <- wisp.serve_static(req, under: "/static", from: priv_dir <> "/static")
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)

  handle_request(req, ctx)
}
