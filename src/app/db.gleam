import sqlight
import gleam/erlang/os.{get_env}

pub fn get_connection() {
  let db_prefix = get_env("DB_PREFIX") 
  let base = "willowisp.sqlite"
  let path = case db_prefix {
    Ok(db_prefix) -> db_prefix <> base
    _ -> base
  }
  sqlight.open(path)
}
pub fn init_db() {
  let assert Ok(conn) = get_connection()
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
