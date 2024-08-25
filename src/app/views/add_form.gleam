import lustre/attribute.{class}
import lustre/element.{type Element}
import lustre/element/html.{form, label, input, text, button}

pub fn add_form() -> Element(t) {
  form([
    class("add_form"),
    attribute.form_action("/add"),
    attribute.method("POST"),
  ],[
    label([
      attribute.for("url")
    ], [
      text("URl to monitor:"),
    ]),
    input([
      attribute.id("url"),
      attribute.name("url"),
      attribute.required(True),
    ]),
    label([
      attribute.for("password")
    ], [
      text("Password:"),
    ]),
    input([
      attribute.id("password"),
      attribute.name("password"),
      attribute.required(True),
    ]),
    button([], [text("Monitor")]),
  ])
}
