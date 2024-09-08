import app/checker
import app/db.{init_db}
import app/web
import gleam/erlang/os.{get_env}
import gleam/erlang/process
import gleam/io
import gleam/otp/supervisor

pub fn main() {
  let _db = init_db()
  io.debug("-----HELLO------")

  let assert Ok(password) = get_env("WILLOWISP_PASSWORD")

  let checker =
    supervisor.worker(checker.start_forever)
    |> supervisor.returning(fn(_, checker) { checker })
  let server = supervisor.worker(web.init(_, password))
  let assert Ok(_) =
    supervisor.start(fn(children) {
      children
      |> supervisor.add(checker)
      |> supervisor.add(server)
    })

  process.sleep_forever()
}
