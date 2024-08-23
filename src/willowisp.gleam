import sqlight
import app/checker
import app/web
import gleam/otp/supervisor
import gleam/erlang/process

fn init_db() {
  use conn <- sqlight.with_connection("./willowisp.sqlite")
  let sql =
    "
    create table if not exists sites (url text, id integer primary key);
    create table if not exists status_checks (
      status int2,
      request_error int2,
      url_error int2,
      siteid integer,
      time DATETIME DEFAULT CURRENT_TIMESTAMP,
      foreign key(siteid) references sites(id)
    );
  "
  let assert Ok(Nil) = sqlight.exec(sql, conn)
}

pub fn main() {
  let _db = init_db()

  let checker = supervisor.worker(checker.start_forever)
    |> supervisor.returning(fn(_, checker) {checker})
  let server = supervisor.worker(web.init(_))
  let assert Ok(_) = supervisor.start(fn(children) {
    children |>
    supervisor.add(checker) |>
    supervisor.add(server)
  })

  process.sleep_forever()
}
