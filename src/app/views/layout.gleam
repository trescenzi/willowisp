import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import gleam/erlang/os.{get_env}

pub fn layout(elements: List(Element(t))) -> Element(t) {
  let assert Ok(discord_url) = get_env("DISCORD_OAUTH_URL")

  html.html([], [
    html.head([], [
      html.title([], "Will o' Wisp"),
      html.meta([
        attribute.name("viewport"),
        attribute.attribute("content", "width=device-width, initial-scale=1"),
      ]),
      html.link([
        attribute.rel("stylesheet"),
        attribute.href("/static/reset.css"),
      ]),
      html.link([attribute.rel("stylesheet"), attribute.href("/static/app.css")]),
    ]),
    html.body([], [
      html.header([], [
        html.div([attribute.class("header")], [
          html.a([attribute.href("/")], [
            html.h1([], [html.text("Will o' Wisp")]),
          ]),
          html.div([attribute.class("links")], [
            html.a([attribute.href(discord_url)], [
              html.text("Get Notified"),
            ]),
            html.a([attribute.class("add"), attribute.href("/add")], [
              html.text("+"),
            ]),
          ]),
        ]),
      ]),
      html.main([], elements),
    ]),
  ])
}
