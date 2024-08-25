import birl
import gleam/bool.{negate}
import gleam/list.{map}
import gleam/int
import lustre/attribute.{classes, class}
import lustre/element.{type Element}
import lustre/element/html.{div, span, text}

pub type Status {
  Status(url: String, status: Bool, time: birl.Time)
}

fn time_display(time: birl.Time) -> Element(t) {
  let time_of_day = birl.get_time_of_day(time)
  let day = birl.get_day(time)
  span([class("datetime")], [
    span([class("date")], [text(int.to_string(day.date)), text("."), text(int.to_string(day.month))]),
    span([class("time")], [text(int.to_string(time_of_day.hour)), text(":"), text(int.to_string(time_of_day.minute))])
  ])
}

fn status_display(status: Status) -> Element(t) {
    div([classes([
      #("status", True), 
      #("live", status.status),
      #("dead", negate(status.status))
    ])], [
      html.a([attribute.href(status.url)], [text(status.url)]),
      span([], [time_display(status.time)]),
      span([classes([
        #("live_check", True), 
        #("live", status.status),
        #("dead", negate(status.status))
      ])], []),
    ])
}

pub fn statuses_display(statuses: List(Status)) -> Element(t) {
  div([class("statuses")], [
    html.h2([], [text("Statuses")]),
    ..map(statuses, status_display),
  ])
}
