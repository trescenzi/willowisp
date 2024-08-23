import sqlight
import gleam/result.{try, map_error}
import gleam/io
import gleam/list.{each}
import gleam/hackney
import gleam/dynamic
import gleam/http/request
import gleam/otp/actor
import gleam/otp/task
import gleam/erlang/process

pub type Error {
  BadUrl
  FailedRequest
  SqlError
}
pub type CheckerMessage {
  CheckAll
  CheckForever
}

pub type CheckerActor = process.Subject(CheckerMessage)

fn get_sites(db db: sqlight.Connection) {
  let sql = "select url, id from sites"
  let url = dynamic.tuple2(dynamic.string, dynamic.int)
  sqlight.query(sql, on: db, with: [], expecting: url)
  |> map_error(with: fn(e) {
    io.debug(e)
    SqlError
  })
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

fn save_status(db db: sqlight.Connection, id siteid: Int, status status: Result(Bool, Error)) {
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
  sqlight.query(sql, on: db, with: input, expecting: dynamic.dynamic)
  |> map_error(with: fn(e) {
    io.debug(e)
    SqlError
  })
}


pub fn start_forever(_) {
  let assert Ok(db) = sqlight.open("./willowisp.sqlite")
  let checker = actor.start(db, handle_message)
  case checker {
    Ok(checker) -> actor.send(checker, CheckForever)
    Error(_checker) -> panic
  }
  checker
}

fn check_all(db: sqlight.Connection) {
  use sites <- try(get_sites(db:))

  each(sites, fn(site) {
    let #(url, id) = site
    let status = check_site(url)
    save_status(db: db, id:, status:)
  })
  Ok(sites)
}

fn loop(db: sqlight.Connection) {
  let _ = check_all(db)
  process.sleep(60000)
  loop(db)
}

pub fn start(_) {
  let assert Ok(db) = sqlight.open("./willowisp.sqlite")
  actor.start(db, handle_message)
}

fn handle_message(
 message: CheckerMessage,
 db: sqlight.Connection
) -> actor.Next(CheckerMessage, sqlight.Connection) {
  case message {
    CheckAll -> {
      let sites = check_all(db)
      case sites {
        Ok(sites) -> each(sites, io.debug)
        Error(_) -> Nil
      }
      actor.continue(db)
    }
    CheckForever -> {
      task.async(fn() { loop(db) })
      actor.continue(db)
    }
  }
}
