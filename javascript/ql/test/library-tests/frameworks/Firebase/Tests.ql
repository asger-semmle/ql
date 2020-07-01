import javascript
private import DataFlow
import ApiGraphs

query SourceNode databaseRef() {
  result = Firebase::Database::ref().asDataFlowNode()
}

query SourceNode snapshot() {
  result = Firebase::snapshot().asDataFlowNode()
}

query SourceNode snapshotCallback() {
  result = Firebase::snapshotCallback().asDataFlowNode()
}

query LocalApiGraph::Node cloudNamespace_() {
  result = Firebase::CloudFunctions::namespace()
}

query SourceNode cloudNamespace() {
  result = Firebase::CloudFunctions::namespace().asDataFlowNode()
}

query SourceNode cloudDatabase() {
  result = Firebase::CloudFunctions::database().asDataFlowNode()
}

query SourceNode cloudRef() {
  result = Firebase::CloudFunctions::ref().asDataFlowNode()
}

query Firebase::FirebaseVal val() { any() }

query HTTP::RequestInputAccess requestInputAccess() { any() }

query HTTP::ResponseSendArgument responseSendArgument() { any() }

query HTTP::RouteHandler routeHandler() { any() }

query SourceNode firebase() { result = Firebase::firebase().asDataFlowNode() }

query SourceNode firebaseUse(string name) { result = Firebase::firebase().getMember(name).getReturn().asDataFlowNode() }

