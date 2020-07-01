import javascript
private import DataFlow

query SourceNode databaseRef() {
  result = Firebase::Database::ref()
}

query SourceNode snapshot() {
  result = Firebase::snapshot()
}

query Firebase::FirebaseVal val() { any() }

query HTTP::RequestInputAccess requestInputAccess() { any() }

query HTTP::ResponseSendArgument responseSendArgument() { any() }

query HTTP::RouteHandler routeHandler() { any() }
