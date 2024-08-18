import gleam/dynamic
import gleam/hackney
import gleam/http/request
import gleam/io
import gleam/list.{each}
import gleam/result.{map_error, try}
import sqlight

pub type Error {
  BadUrl
  FailedRequest
  SqlError
}

fn check_site(url: String) {
  use request <- try(
    url
    |> request.to
    |> map_error(with: fn(_e) { BadUrl }),
  )

  use response <- try(
    request
    |> hackney.send
    |> map_error(with: fn(_e) { FailedRequest }),
  )

  case response.status {
    200 -> Ok(True)
    _ -> Ok(False)
  }
}

fn save_status(siteid: Int, status: Result(Bool, Error)) {
  use conn <- sqlight.with_connection("./willowisp.sqlite")
  let id = sqlight.int(siteid)
  let input = case status {
    Ok(True) -> [
      sqlight.bool(True),
      sqlight.bool(False),
      sqlight.bool(False),
      id,
    ]
    Ok(False) -> [
      sqlight.bool(False),
      sqlight.bool(False),
      sqlight.bool(False),
      id,
    ]
    Error(BadUrl) -> [
      sqlight.bool(False),
      sqlight.bool(False),
      sqlight.bool(True),
      id,
    ]
    Error(FailedRequest) -> [
      sqlight.bool(False),
      sqlight.bool(True),
      sqlight.bool(False),
      id,
    ]
    _ -> []
  }

  let sql =
    "
    insert into status_checks 
           (status, request_error, url_error, siteid)
    values (?, ?, ?, ?)
  "
  sqlight.query(sql, on: conn, with: input, expecting: dynamic.dynamic)
  |> map_error(with: fn(e) {
    io.debug(e)
    SqlError
  })
}

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
      foreign key(siteid) references sites(id)
    );
  "
  let assert Ok(Nil) = sqlight.exec(sql, conn)
}

fn get_sites() {
  use conn <- sqlight.with_connection("./willowisp.sqlite")
  let sql = "select url, id from sites"
  let url = dynamic.tuple2(dynamic.string, dynamic.int)
  sqlight.query(sql, on: conn, with: [], expecting: url)
  |> map_error(with: fn(e) {
    io.debug(e)
    SqlError
  })
}

pub fn main() {
  let _db = init_db()

  use sites <- try(get_sites())

  each(sites, fn(site) {
    let #(url, id) = site
    let status = check_site(url)
    save_status(id, status)
  })

  Ok("awesome")
}
