import app/db.{get_connection}
import sqlight
import gleam/result.{try, map_error}
import gleam/io
import gleam/list.{each}
import gleam/hackney
import gleam/dynamic
import gleam/http/request
import gleam/otp/actor
import gleam/otp/task
import gleam/erlang/process.{type Subject}

pub type Error {
  BadUrl
  FailedRequest
  SqlError
}
pub type CheckerMessage {
  CheckAll
  CheckSite(url: String)
  CheckSiteSync(reply_with: Subject(Result(Nil, Nil)), url: String)
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

fn compute_status_for_insert(status: Result(Bool, Error)) {
  case status {
    Ok(True) -> [
      sqlight.bool(True),
      sqlight.bool(False),
      sqlight.bool(False),
    ]
    Ok(False) -> [
      sqlight.bool(False),
      sqlight.bool(False),
      sqlight.bool(False),
    ]
    Error(BadUrl) -> [
      sqlight.bool(False),
      sqlight.bool(False),
      sqlight.bool(True),
    ]
    Error(FailedRequest) -> [
      sqlight.bool(False),
      sqlight.bool(True),
      sqlight.bool(False),
    ]
    _ -> []
  }
}

fn save_status(db db: sqlight.Connection, id siteid: Int, status status: Result(Bool, Error)) {
  let id = sqlight.int(siteid)
  let input = [id, ..compute_status_for_insert(status)]
  let sql = "
    insert into status_checks 
           (siteid, status, request_error, url_error)
    values (?, ?, ?, ?)
  "
  sqlight.query(sql, on: db, with: input, expecting: dynamic.dynamic)
  |> map_error(with: fn(e) {
    io.debug(e)
    SqlError
  })
}


pub fn start_forever(_) {
  let assert Ok(db) = get_connection()
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
    save_status(db:, id:, status:)
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
    CheckSiteSync(client, url) -> {
      let status = check_site(url)
      let input = compute_status_for_insert(status)
      let sql = "
        insert into status_checks 
               (siteid, status, request_error, url_error)
        select id, ?, ?, ?
        from sites
        where url = ?
      "
      let _ = sqlight.query(sql, on: db, with: list.append(input, [sqlight.text(url)]), expecting: dynamic.dynamic)
      |> map_error(with: fn(e) {
        io.debug(e)
        SqlError
      })
      process.send(client, Ok(Nil))
      actor.continue(db)
    }
    CheckSite(url) -> {
      let status = check_site(url)
      let input = compute_status_for_insert(status)
      let sql = "
        insert into status_checks 
               (siteid, status, request_error, url_error)
        select id, ?, ?, ?
        from sites
        where url = ?
      "
      let _ = sqlight.query(sql, on: db, with: list.append(input, [sqlight.text(url)]), expecting: dynamic.dynamic)
      |> map_error(with: fn(e) {
        io.debug(e)
        SqlError
      })
      actor.continue(db)
    }
    CheckForever -> {
      task.async(fn() { loop(db) })
      actor.continue(db)
    }
  }
}
