import app/views/layout.{layout}
import app/middleware
import gleam/io
import gleam/http.{Get, Post}
import gleam/result
import gleam/dynamic
import gleam/list
import sqlight
import wisp.{type Request, type Response}
import app/views/add_form.{add_form}
import lustre/element.{to_document_string_builder}

pub fn add(req: Request, ctx: middleware.Context) -> Response {

  case req.method {
    Get -> show_form()
    Post -> handle_submission(req, ctx)
    _ -> wisp.method_not_allowed(allowed: [Get, Post])
  }
}

fn show_form() {
    [add_form()]
      |> layout
      |> to_document_string_builder
      |> wisp.html_response(200) 
}

type InsertError {
  Password
  Insert
  Form
}

fn handle_submission(req, ctx: middleware.Context) {
  use formdata <- wisp.require_form(req)
  let app_password = ctx.password

  let insert = {
    use url <- result.try(
      list.key_find(formdata.values, "url")
      |> result.map_error(fn(_) { Error(Form) })
    )
    use password <- result.try(
      list.key_find(formdata.values, "password")
      |> result.map_error(fn(_) { Error(Form) })
    )
    io.debug(url)
    io.debug(password)
    case password == app_password {
      True -> Ok(insert(url, ctx.db))
      False -> Error(Error(Password))
    }
  }

  case insert {
    Ok(_) -> wisp.redirect(to: "/")
    Error(Error(Password)) -> wisp.response(403)
    Error(Error(Form)) -> wisp.unprocessable_entity()
    Error(Error(Insert)) -> wisp.internal_server_error()
    _ -> wisp.internal_server_error()
  }
}

fn insert(url, db) -> Result(Int, InsertError) {
    let sql = "insert into sites (url) values (?) returning id"
    let id = sqlight.query(sql, on: db, with: [sqlight.text(url)], expecting: dynamic.element(0, dynamic.int))
    case id {
      Ok(ids) -> case list.first(ids) {
        Ok(id) -> Ok(id)
        Error(_) -> Error(Insert)
      }
      Error(_) -> Error(Insert)
    }
}
