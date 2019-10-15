/**
 * Provides a taint-tracking configuration for reasoning about DOM-based
 * cross-site scripting vulnerabilities.
 */

import javascript
import semmle.javascript.security.TaintedUrlSuffix

module DomBasedXss {
  import Xss::DomBasedXss

  /**
   * Holds if `node` starts with `<`, possibly preceded by whitespace, indicating
   * that the jQuery `$` function will interpret it as HTML.
   */
  predicate hasHtmlPrefix(DataFlow::Node node) {
    node.getStringValue().regexpMatch("(?s)\\s*<.*")
    or
    hasHtmlPrefix(node.getAPredecessor())
    or
    hasHtmlPrefix(node.(StringOps::Concatenation).getFirstOperand())
  }

  /**
   * A taint-tracking configuration for reasoning about XSS.
   */
  class Configuration extends TaintTracking::Configuration {
    Configuration() { this = "DomBasedXss" }

    override predicate isSource(DataFlow::Node source) { source instanceof Source }

    override predicate isSource(DataFlow::Node source, DataFlow::FlowLabel lbl) {
      source = DOM::locationSource() and
      lbl = TaintedUrlSuffix::label()
    }

    override predicate isSink(DataFlow::Node sink, DataFlow::FlowLabel lbl) {
      sink.(Sink).getAFlowLabel() = lbl
    }

    override predicate isSanitizer(DataFlow::Node node) {
      super.isSanitizer(node)
      or
      node instanceof Sanitizer
    }

    override predicate isAdditionalFlowStep(DataFlow::Node src, DataFlow::Node dst, DataFlow::FlowLabel srclbl, DataFlow::FlowLabel dstlbl) {
      // When prefixing '<' onto a tainted URL suffix, transition to general taint so it can reach potential jQuery sinks.
      exists(StringOps::ConcatenationRoot operator |
        hasHtmlPrefix(operator) and
        src = operator.getAnOperand() and
        dst = operator and
        srclbl = TaintedUrlSuffix::label() and
        dstlbl.isTaint()
      )
    }
  }

  /** A source of remote user input, considered as a flow source for DOM-based XSS. */
  class RemoteFlowSourceAsSource extends Source {
    RemoteFlowSourceAsSource() { this instanceof RemoteFlowSource }
  }
}
