import gleam/erlang/os.{get_env}
import gleam/io.{debug}
import sqlight

pub fn get_connection() {
  let path = get_db_path()
  sqlight.open(path)
}

pub fn get_db_path() {
  let db_prefix = get_env("DB_PREFIX")
  let base = "willowisp.sqlite"
  let path = case db_prefix {
    Ok(db_prefix) -> db_prefix <> base
    _ -> "./" <> base
  }
  debug("DB PATH " <> path)
  path
}

pub fn init_db() {
  let assert Ok(conn) = get_connection()
  let sql =
    "
    create table if not exists sites (url text, id integer primary key);
    create table if not exists status_checks(
      status int2,
      request_error int2,
      url_error int2,
      siteid integer,
      time datetime default current_timestamp,
      foreign key(siteid) references sites(id)
    );
    create table if not exists discord_users(
      id integer primary key,
      access_token text,
      refresh_token text not null,
      expiry datetime
    );
    create table if not exists discord_notifications(
      userid integer,
      siteid integer,
      foreign key(siteid) references sites(id)
      foreign key(userid) references discord_users(id)
    );
  "
  let assert Ok(Nil) = sqlight.exec(sql, conn)
  debug("DB crerated")
}
