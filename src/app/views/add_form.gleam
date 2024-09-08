import lustre/attribute.{action, class, for, id, method, name, required}
import lustre/element.{type Element}
import lustre/element/html.{button, form, input, label, text}

pub fn add_form() -> Element(t) {
  form([class("add_form"), action("/add"), method("POST")], [
    label([for("url")], [text("URl to monitor:")]),
    input([id("url"), name("url"), required(True)]),
    label([for("password")], [text("Password:")]),
    input([id("password"), name("password"), required(True)]),
    button([], [text("Monitor")]),
  ])
}
