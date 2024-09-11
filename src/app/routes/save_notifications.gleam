import app/middleware
import app/views/layout.{layout}
import app/views/save_notice.{notice}
import gleam/dynamic
import gleam/http.{Get, Post}
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor.{call}
import gleam/result
import lustre/element.{to_document_string_builder}
import sqlight
import wisp.{type Request, type Response}

pub fn save_notifications(req: Request, ctx: middleware.Context) -> Response {
  case req.method {
    Get -> show_notice()
    Post -> handle_submission(req, ctx)
    _ -> wisp.method_not_allowed(allowed: [Get, Post])
  }
}

fn show_notice() {
  [notice()]
  |> layout
  |> to_document_string_builder
  |> wisp.html_response(200)
}

type InsertError {
  Password
  MissingUserID
  SqlError
}

fn handle_submission(req: Request, ctx: middleware.Context) -> Response {
  use formdata <- wisp.require_form(req)

  let insert = {
    use user_id <- result.try(
      list.key_find(formdata.values, "user_id")
      |> result.try(fn(id) { int.parse(id) })
      |> result.replace_error(MissingUserID),
    )
    let ids: List(Result(Int, Nil)) =
      list.fold(over: formdata.values, from: [], with: fn(acc, value) {
        case value.1 {
          "on" -> [int.parse(value.0), ..acc]
          _ -> acc
        }
      })
    io.debug(ids)
    io.debug(user_id)
    use insert_result <- result.try(
      insert(ids, ctx.db, user_id)
      |> result.map_error(fn(e) {
        io.debug(e)
        SqlError
      }),
    )
    Ok(insert_result)
  }

  case insert {
    Ok(_) -> {
      wisp.redirect(to: "/")
    }
    Error(Password) -> wisp.response(403)
    Error(MissingUserID) -> wisp.unprocessable_entity()
    Error(SqlError) -> wisp.internal_server_error()
  }
}

fn insert(
  site_ids: List(Result(Int, Nil)),
  db: sqlight.Connection,
  user_id: Int,
) {
  io.debug(site_ids)
  let input_string =
    list.fold(site_ids, "", fn(values, _id) {
      let new_value = "(?, ?)"
      case values {
        "" -> new_value
        _ -> values <> "," <> new_value
      }
    })
  io.debug(input_string)
  let sql =
    "insert into discord_notifications (userid, siteid) values "
    <> input_string
    <> ";"
  io.debug(sql)
  let user_input = sqlight.int(user_id)
  let inputs =
    list.fold(site_ids, [], fn(values, id) {
      case id {
        Ok(id) -> [user_input, sqlight.int(id), ..values]
        Error(_) -> values
      }
    })
  sqlight.query(sql, on: db, with: inputs, expecting: dynamic.dynamic)
}
