private import javascript
import meta.Metrics

/**
 * Gets the RHS of an assignment to `root.path` or a `SourceNode` that
 * refer to `root.path`.
 *
 * Collectively we call these "relevant references".
 */
DataFlow::Node relevantReferenceTo(AccessPath::Root root, string path) {
  path != "" and
  (
    result = AccessPath::getAReferenceTo(root, path).(DataFlow::SourceNode)
    or
    result = AccessPath::getAnAssignmentTo(root, path)
    or
    // We only step through global access paths that are assigned in a unique file,
    // so only consider such accesses relevant.
    root.isGlobal() and
    AccessPath::isAssignedInUniqueFile(path) and
    (
      result = AccessPath::getAReferenceTo(path).(DataFlow::SourceNode)
      or
      result = AccessPath::getAnAssignmentTo(path)
    )
  )
}

/** Gets the number of relevant references to `root.path`. */
int numReferencesTo(AccessPath::Root root, string path) {
  result = strictcount(DataFlow::Node node | node = relevantReferenceTo(root, path))
}

/** Holds if there is more than one relevant reference to `root.path`. */
predicate accessPathHasAliases(AccessPath::Root root, string path) {
  numReferencesTo(root, path) > 1
}

/**
 * Holds if `node` refers to an access path with more than one relevant reference,
 * implying that we have found one or more aliases for `node`.
 */
predicate nodeHasAliases(DataFlow::Node node) {
  exists(AccessPath::Root root, string path |
    node = relevantReferenceTo(root, path) and
    accessPathHasAliases(root, path)
  )
}
