import javascript
private import internal.FlowSteps

private newtype TTrackSummary = MkTrackSummary(boolean hasReturn, boolean hasCall) {
  (hasReturn = true or hasReturn = false) and
  (hasCall = true or hasCall = false)
}

/**
 * Same as `PathSummary` except without flow labels.
 */
class TrackSummary extends TTrackSummary {
  Boolean hasReturn;

  Boolean hasCall;

  TrackSummary() { this = MkTrackSummary(hasReturn, hasCall) }
  
  /** Indicates whether the path represented by this summary contains any return steps. */
  boolean hasReturn() { result = hasReturn }

  /** Indicates whether the path represented by this summary contains any call steps. */
  boolean hasCall() { result = hasCall }
  
  predicate start() {
    hasReturn = false and hasCall = false
  }

  /**
   * Gets the summary for the path obtained by appending `that` to `this`.
   *
   * Note that a path containing a `return` step cannot be appended to a path containing
   * a `call` step in order to maintain well-formedness.
   */
  TrackSummary append(TrackSummary that) {
    exists(Boolean hasReturn2, Boolean hasCall2 |
      that = MkTrackSummary(hasReturn2, hasCall2)
    |
      result = MkTrackSummary(hasReturn.booleanOr(hasReturn2), hasCall.booleanOr(hasCall2)) and
      // avoid constructing invalid paths
      not (hasCall = true and hasReturn2 = true)
    )
  }

  /**
   * Gets the summary for the path obtained by appending `this` to `that`.
   */
  TrackSummary prepend(TrackSummary that) { result = that.append(this) }

  /** Gets a textual representation of this path summary. */
  string toString() {
    exists(string withReturn, string withCall |
      (if hasReturn = true then withReturn = "with" else withReturn = "without") and
      (if hasCall = true then withCall = "with" else withCall = "without")
    |
      result = "path " + withReturn + " return steps and " + withCall + " call steps"
    )
  }
}


module TrackSummary {
  /**
   * Gets a summary describing a path without any calls or returns.
   */
  TrackSummary level() { result = MkTrackSummary(false, false) }

  /**
   * Gets a summary describing a path with one or more calls, but no returns.
   */
  TrackSummary call() { result = MkTrackSummary(false, true) }

  /**
   * Gets a summary describing a path with one or more returns, but no calls.
   */
  TrackSummary return() { result = MkTrackSummary(true, false) }

  /**
   * INTERNAL: Use `SourceNode.track()` instead.
   */
  predicate step(DataFlow::SourceNode pred, DataFlow::SourceNode succ, TrackSummary summary) {
    exists (DataFlow::Node predNode | pred.flowsTo(predNode) |
      // Flow through properties of objects
      propertyFlowStep(predNode, succ) and
      summary = level()
      or
      // Flow through global variables
      globalFlowStep(predNode, succ) and
      summary = level()
      or
      // Flow into function
      callStep(predNode, succ) and
      summary = call()
      or
      // Flow out of function
      returnStep(predNode, succ) and
      summary = return()
    )
    or
    fieldStep(pred, succ) and
    summary = level()
  }
}
