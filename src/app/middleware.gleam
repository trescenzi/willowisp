import sqlight.{type Connection}
import app/checker.{type CheckerActor}

pub type Context {
  Context(db: Connection, checker: CheckerActor)
}
