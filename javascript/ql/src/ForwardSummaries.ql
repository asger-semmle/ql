import javascript
private import ApiGraphs
private import external.ExternalArtifact

query predicate sinkSummary(
  string tag, LocalApiGraph::UseNode u, DataFlow::FlowLabel lbl, string cfg
) {
  tag = "sinkSummary" and
  exists(ExternalData e, RemoteApiGraph::UseNode nd |
    e.getField(0) = "sinkSummary" and
    nd.getPath() = e.getField(1) and
    lbl = e.getField(2) and
    cfg = e.getField(3) and
    u = LocalApiGraph::forwardNode(nd)
  )
}

query predicate sourceSummary(
  string tag, LocalApiGraph::DefNode d, DataFlow::FlowLabel lbl, string cfg
) {
  tag = "sourceSummary" and
  exists(ExternalData e, RemoteApiGraph::DefNode nd |
    e.getField(0) = "sourceSummary" and
    nd.getPath() = e.getField(1) and
    lbl = e.getField(2) and
    cfg = e.getField(3) and
    d = LocalApiGraph::forwardNode(nd)
  )
}
