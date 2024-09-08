//import lustre/attribute.{class, for, form_action, id, method, name, required}
import lustre/element.{type Element}
import lustre/element/html

pub fn notice() -> Element(t) {
  html.div([], [html.h2([], [html.text("Hey something went wrong!")])])
}
