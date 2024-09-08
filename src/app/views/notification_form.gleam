import gleam/int.{to_string}
import gleam/list
import lustre/attribute.{action, class, for, method, name}
import lustre/element.{type Element}
import lustre/element/html.{button, input, label, text}

pub type SitePreference {
  SitePreference(url: String, id: Int, selected: Bool)
}

pub fn form(sites: List(SitePreference), user_id: Int) -> Element(t) {
  html.div([], [
    html.h2([], [text("Select notifications you'd like:")]),
    html.form(
      [
        class("notification_form"),
        action("/save_notifications"),
        method("POST"),
      ],
      list.reverse([
        button([], [text("Save Preferences")]),
        input([
          name("user_id"),
          attribute.id("user_id"),
          attribute.value(to_string(user_id)),
          attribute.type_("hidden"),
        ]),
        ..list.flat_map(sites, notify_checkbox)
      ]),
    ),
  ])
}

fn notify_checkbox(site: SitePreference) -> List(Element(t)) {
  let id = to_string(site.id)
  [
    label([for(id)], [text(site.url)]),
    input([attribute.type_("checkbox"), attribute.id(id), name(id)]),
  ]
}
