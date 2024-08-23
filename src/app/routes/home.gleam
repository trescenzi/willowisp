import app/middleware.{type Context}
import gleam/dynamic
import gleam/result
import gleam/list
import sqlight
import gleam/string_builder
import wisp.{type Request, type Response}
//import birl

pub fn home(_req: Request, ctx: Context) -> Response {
  // Apply the middleware stack for this request/response.
  //use _req <- web.middleware(req)

  let sql = "
        WITH statuses AS (
        SELECT
            sites.url as url,
            status.status as status,
            status.time as timestamp,
            row_number() over
              (partition by sites.url order by status.time desc)
            AS rn
        FROM
            status_checks status
        join sites on sites.id = status.siteid
    )
    SELECT
        url,
        status,
        timestamp
    FROM
        statuses
    WHERE
        rn = 1;
  "
  let status_check = dynamic.tuple3(dynamic.string, dynamic.int, dynamic.string)
  let statuses_result = sqlight.query(sql, on: ctx.db, with: [], expecting: status_check)
   |> result.map(fn(status) {
      list.map(status, fn(status) {
        let #(url, status, time) = status
        // birl.parse(time)
        #(url, case status { 1 -> True 0 -> False _ -> False }, time)
      })
   })
  let body = case statuses_result {
    Ok(statuses) -> list.fold(over: statuses, from: "", with: fn(acc, status) {
      let #(url, status, time) = status
      acc <>
      "<br/>" <> 
      url <> " " <>
      case status {
        True -> "Alive"
        False -> "Dead"
      } <> " " <>
      time
    })
    Error(_) -> ""
  }
  // Later we'll use templates, but for now a string will do.
  let body = string_builder.from_string(body)

  // Return a 200 OK response with the body and a HTML content type.
  wisp.html_response(body, 200)
}
