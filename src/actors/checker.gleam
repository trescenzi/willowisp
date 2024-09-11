import app/discord/channel.{create_bot_dm_channel, send_bot_message_to_channel}
import app/db.{get_connection}
import gleam/dynamic
import gleam/erlang/process.{type Subject}
import gleam/hackney
import gleam/http/request
import gleam/io
import gleam/list.{each}
import gleam/int
import gleam/otp/actor
import gleam/otp/task
import gleam/result.{map_error, try}
import sqlight

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

pub type CheckerActor =
  process.Subject(CheckerMessage)

fn get_sites(db db: sqlight.Connection) {
  let sql = "select url, id from sites"
  let url = dynamic.tuple2(dynamic.string, dynamic.int)
  sqlight.query(sql, on: db, with: [], expecting: url)
  |> map_error(with: fn(e) {
    io.debug(e)
    SqlError
  })
}

fn notify_users(url: String) {
  // if we cannot connect this task just blows up, that's ok
  // we'll likely notify them next time just fine
  let assert Ok(connection) = get_connection()
  let sql = "select dn.userid from discord_notifications dn join sites s on s.id = dn.siteid where s.url = ?"
  use userids <- result.try(
    sqlight.query(
      sql,
      on: connection,
      with: [sqlight.text(url)],
      expecting: dynamic.element(0, dynamic.int),
    )
  )
  io.debug("notifying the below users")
  io.debug(userids)

  each(userids, fn(id) {
    io.debug("notifying")
    io.debug(id)
    use channel <- result.try(create_bot_dm_channel(int.to_string(id)))
    send_bot_message_to_channel(url <> " is down", channel:)
  })

  Ok("notified")
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
    Ok(True) -> [sqlight.bool(True), sqlight.bool(False), sqlight.bool(False)]
    Ok(False) -> [sqlight.bool(False), sqlight.bool(False), sqlight.bool(False)]
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

fn save_status(
  db db: sqlight.Connection,
  id siteid: Int,
  status status: Result(Bool, Error),
) {
  let id = sqlight.int(siteid)
  let input = [id, ..compute_status_for_insert(status)]
  let sql =
    "
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
    task.async(fn() { 
      case status {
        Ok(_) -> Ok("")
        Error(_) -> {
          io.debug("notifying users about" <> url)
          notify_users(url)
        }
      }
    })
    save_status(db:, id:, status:)
  })
  Ok(sites)
}

fn loop(db: sqlight.Connection) {
  let _ = check_all(db)
  process.sleep(60_000)
  loop(db)
}

pub fn start(_) {
  let assert Ok(db) = sqlight.open("./willowisp.sqlite")
  actor.start(db, handle_message)
}

fn handle_message(
  message: CheckerMessage,
  db: sqlight.Connection,
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
      let sql =
        "
        insert into status_checks 
               (siteid, status, request_error, url_error)
        select id, ?, ?, ?
        from sites
        where url = ?
      "
      let _ =
        sqlight.query(
          sql,
          on: db,
          with: list.append(input, [sqlight.text(url)]),
          expecting: dynamic.dynamic,
        )
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
      let sql =
        "
        insert into status_checks 
               (siteid, status, request_error, url_error)
        select id, ?, ?, ?
        from sites
        where url = ?
      "
      let _ =
        sqlight.query(
          sql,
          on: db,
          with: list.append(input, [sqlight.text(url)]),
          expecting: dynamic.dynamic,
        )
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
