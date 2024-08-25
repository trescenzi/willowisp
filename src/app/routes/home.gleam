import app/middleware.{type Context}
import gleam/dynamic
import gleam/result
import gleam/io
import gleam/list
import sqlight
import birl
import gleam/string_builder
import wisp.{type Request, type Response}
import lustre/element.{to_document_string_builder}
import app/views/status.{statuses_display, Status}
import app/views/layout.{layout}

pub fn home(_req: Request, ctx: Context) -> Response {
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
        io.debug(time)
        Status(
          url, 
          case status { 1 -> True 0 -> False _ -> False },
          case birl.from_naive(time) { Ok(t) -> t Error(Nil) -> birl.now() }
        )
      })
   })
  case statuses_result {
    Ok(statuses) -> [statuses_display(statuses)]
                    |> layout
                    |> to_document_string_builder
                    |> wisp.html_response(200) 
    Error(_) -> string_builder.from_string("")
                |> wisp.html_response(500)
  }
}
