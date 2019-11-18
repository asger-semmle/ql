/**
 * Provides a flow label for reasoning about URLs with a tainted query and fragment part,
 * which we collectively refer to as the "suffix" of the URL.
 */
import javascript

module TaintedUrlSuffix {
  private import DataFlow

  /**
   * The flow label representing a URL with a tainted query and fragment part.
   *
   * Can also be accessed using `TaintedUrlSuffix::label()`.
   */
  class TaintedUrlSuffixLabel extends FlowLabel {
    TaintedUrlSuffixLabel() {
      this = "tainted-url-suffix"
    }
  }

  /**
   * Gets the flow label representing a URL with a tainted query and fragment part.
   */
  FlowLabel label() { result instanceof TaintedUrlSuffixLabel }

  /**
   * Holds if there is a flow step `src -> dst` involving the URL suffix taint label.
   *
   * This handles steps through string operations, promises, URL parsers, and URL accessors.
   */
  predicate step(Node src, Node dst, FlowLabel srclbl, FlowLabel dstlbl) {
    srclbl = label() and
    dstlbl = label() and
    (
      StringConcatenation::taintStep(src, dst)
      or
      TaintTracking::reactComponentStep(src, dst)
      or
      any(TaintTracking::PersistentStorageTaintStep step).step(src, dst)
      or
      any(Vue::InstanceHeapStep step).step(src, dst)
      or
      any(UriLibraryStep step).step(src, dst)
      or
      promiseTaintStep(src, dst)
      or
      exists(MethodCallNode call, string name |
        name = call.getMethodName() and
        src = call.getReceiver() and
        dst = call
      |
        name = "toString" or
        name = "valueOf" or
        name = "toUpperCase" or
        name = "toLowerCase" or
        name = "toLocaleUpperCase" or
        name = "toLocaleLowerCase" or
        name = "trim" or
        name = "trimEnd" or
        name = "trimLeft" or
        name = "trimRight" or
        name = "trimStart" or
        name = "normalize"
      )
      or
      exists(InvokeNode call, string name |
        call = globalVarRef(name).getAnInvocation() and
        src = call.getArgument(0) and
        dst = call
      |
        name = "String" or
        name = "URL"
      )
      or
      // Step through properties of various kinds of URL objects.
      exists(PropRead read, string name |
        name = read.getPropertyName() and
        src = read.getBase() and
        dst = read
      |
        name = "href" or

        // Note that the '#' and '?' symbols are included in 'search' and 'hash'.
        name = "search" or
        name = "hash" or

        // 'searchParams' and 'hashParams' are Map objects. This step works in conjunction
        // with a step through 'get' calls.
        name = "searchParams" or 
        name = "hashParams"
      )
    )
    or
    srclbl = label() and
    dstlbl.isTaint() and
    (
      exists(MethodCallNode call, string name |
        src = call.getReceiver() and
        dst = call and
        name = call.getMethodName()
      |
        // Substring that is not a prefix
        (name = "substring" or name = "substr" or name = "slice") and
        not call.getArgument(0).getIntValue() = 0
        or
        // Split around '#' or '?' and extract the suffix
        name = "split" and
        call.getArgument(0).getStringValue().regexpMatch("[#?]") and
        not exists(call.getAPropertyRead("0")) // Avoid false flow to the prefix
        or
        // Replace '#' and '?' with nothing
        name = "replace" and
        call.getArgument(0).getStringValue().regexpMatch("[#?]") and
        call.getArgument(1).getStringValue() = ""
        or
        // The `get` call in `url.searchParams.get(x)` and `url.hashParams.get(x)`
        // The step should be safe since nothing else reachable by this flow label supports a method named 'get'.
        name = "get"
        or
        // Methods on URL objects from the Closure library
        name = "getDecodedQuery" or
        name = "getFragment" or
        name = "getParameterValue" or
        name = "getParameterValues" or
        name = "getQueryData"
      )
      or
      exists(PropRead read |
        src = read.getBase() and
        dst = read and
        // Unlike the `search` property, the `query` property from `url.parse` does not include the `?`.
        read.getPropertyName() = "query"
      )
      or
      // Assume calls to regexp.exec always extract query/fragment parameters.
      exists(MethodCallNode call |
        call = any(RegExpLiteral re).flow().(DataFlow::SourceNode).getAMethodCall("exec") and
        src = call.getArgument(0) and
        dst = call
      )
    )
  }

  /**
   * Contributes `step` to the flow step relation.
   */
  private class TaintedUrlSuffixStep extends AdditionalFlowStep {
    TaintedUrlSuffixStep() {
      TaintedUrlSuffix::step(this, _, _, _)
    }

    override predicate step(Node src, Node dst, FlowLabel srclbl, FlowLabel dstlbl) {
      src = this and
      TaintedUrlSuffix::step(src, dst, srclbl, dstlbl)
    }
  }
}
