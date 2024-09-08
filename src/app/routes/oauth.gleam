import app/discord/oauth.{type AuthResponse}
import app/discord/user.{type DiscordUser}
import app/middleware
import app/views/layout.{layout}
import app/views/notification_form.{SitePreference}
import birl
import birl/duration.{seconds}
import gleam/dynamic
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import lustre/element.{to_document_string_builder}
import sqlight
import wisp.{type Request, type Response}

pub type PageError {
  MissingCode
  FailedOauthRequest
  FailedOauthDecode
  FailedCreateUser
  FailedPreferencesGet
  MeFailure
}

fn render_error(error: PageError) -> Response {
  io.debug(error)
  wisp.redirect(to: "/")
}

pub fn oauth(req: Request, ctx: middleware.Context) -> Response {
  let data = {
    let query = wisp.get_query(req)
    use code <- result.try(
      list.key_find(query, "code")
      |> result.replace_error(MissingCode),
    )
    use oauth_response <- result.try(
      oauth.auth_code_request(code)
      |> result.replace_error(FailedOauthRequest),
    )
    io.debug(oauth_response.body)
    use oauth_codes <- result.try(
      oauth.decode_auth_code(oauth_response.body)
      |> result.replace_error(FailedOauthDecode),
    )
    use user <- result.try(
      user.me(oauth_codes.access_token)
      |> result.replace_error(MeFailure),
    )
    io.debug(user.id)
    use id <- result.try(
      create_or_update_user(oauth_codes, user, ctx.db)
      |> result.replace_error(FailedCreateUser),
    )

    use preferences <- result.try(
      current_preferences(id, ctx.db)
      |> result.replace_error(FailedPreferencesGet),
    )

    io.debug("Created user" <> int.to_string(id))
    Ok(#(preferences, id))
  }

  io.debug(data)
  case data {
    Ok(data) ->
      [notification_form.form(data.0, data.1)]
      |> layout
      |> to_document_string_builder
      |> wisp.html_response(200)
    Error(e) -> render_error(e)
  }
}

fn create_or_update_user(auth_response: AuthResponse, user: DiscordUser, db) {
  let sql =
    "
    insert into discord_users (id, access_token, refresh_token, expiry)
    values (?, ?, ?, ?)
    on conflict(id)
    do update set
      refresh_token=excluded.refresh_token,
      access_token=excluded.access_token,
      expiry=excluded.expiry
    returning id
  "
  let distance = seconds(auth_response.expires_in - 1000)
  let expiration =
    birl.now()
    |> birl.add(distance)
    |> birl.to_iso8601

  use id <- result.try(
    sqlight.query(
      sql,
      on: db,
      with: [
        sqlight.text(user.id),
        sqlight.text(auth_response.access_token),
        sqlight.text(auth_response.refresh_token),
        sqlight.text(expiration),
      ],
      expecting: dynamic.element(0, dynamic.int),
    )
    |> result.replace_error(Nil),
  )
  use first <- result.try(list.first(id))
  Ok(first)
}

fn current_preferences(user_id: Int, db: sqlight.Connection) {
  let sql =
    "select s.id, s.url, 
    case when dn.userid is null then false else true end as notify 
    from sites s left join discord_notifications dn on 
    s.id = dn.siteid and dn.userid = ?;
  "
  sqlight.query(
    sql,
    on: db,
    with: [sqlight.int(user_id)],
    expecting: dynamic.tuple3(dynamic.int, dynamic.string, dynamic.int),
  )
  |> result.map(fn(rows) {
    list.map(rows, fn(row) {
      SitePreference(row.1, row.0, case row.2 {
        1 -> True
        _ -> False
      })
    })
  })
}
