/**
 * Provides default sources, sinks and sanitizers for reasoning about
 * unvalidated URL redirection problems on the client side, as well as
 * extension points for adding your own.
 */

import javascript
import semmle.javascript.security.dataflow.RemoteFlowSources
import semmle.javascript.security.TaintedUrlSuffix
import UrlConcatenation

module ClientSideUrlRedirect {
  /**
   * A data flow source for unvalidated URL redirect vulnerabilities.
   */
  abstract class Source extends DataFlow::Node { }

  /**
   * A data flow sink for unvalidated URL redirect vulnerabilities.
   */
  abstract class Sink extends DataFlow::Node { }

  /**
   * A sanitizer for unvalidated URL redirect vulnerabilities.
   */
  abstract class Sanitizer extends DataFlow::Node { }

  /**
   * DEPRECATED. Use `TaintedUrlSuffix::TaintedUrlSuffixLabel` instead.
   */
  deprecated
  class DocumentUrl = TaintedUrlSuffix::TaintedUrlSuffixLabel;

  /** A source of remote user input, considered as a flow source for unvalidated URL redirects. */
  class RemoteFlowSourceAsSource extends Source {
    RemoteFlowSourceAsSource() { this instanceof RemoteFlowSource }
  }

  /**
   * A sink which is used to set the window location.
   */
  class LocationSink extends Sink, DataFlow::ValueNode {
    LocationSink() {
      // A call to a `window.navigate` or `window.open`
      exists(string name |
        name = "navigate" or
        name = "open" or
        name = "openDialog" or
        name = "showModalDialog"
      |
        this = DataFlow::globalVarRef(name).getACall().getArgument(0)
      )
      or
      // A call to `location.replace` or `location.assign`
      exists(DataFlow::MethodCallNode locationCall, string name |
        locationCall = DOM::locationRef().getAMethodCall(name) and
        this = locationCall.getArgument(0)
      |
        name = "replace" or name = "assign"
      )
      or
      // An assignment to `location`
      exists(Assignment assgn | isLocation(assgn.getTarget()) and astNode = assgn.getRhs())
      or
      // An assignment to `location.href`, `location.protocol` or `location.hostname`
      exists(DataFlow::PropWrite pw, string propName |
        pw = DOM::locationRef().getAPropertyWrite(propName) and
        this = pw.getRhs()
      |
        propName = "href" or propName = "protocol" or propName = "hostname"
      )
      or
      // A redirection using the AngularJS `$location` service
      exists(AngularJS::ServiceReference service |
        service.getName() = "$location" and
        this.asExpr() = service.getAMethodCall("url").getArgument(0)
      )
    }
  }

  /**
   * An expression that may be interpreted as the URL of a script.
   */
  abstract class ScriptUrlSink extends Sink { }

  /**
   * An argument expression to `new Worker(...)`, viewed as
   * a `ScriptUrlSink`.
   */
  class WebWorkerScriptUrlSink extends ScriptUrlSink, DataFlow::ValueNode {
    WebWorkerScriptUrlSink() {
      this = DataFlow::globalVarRef("Worker").getAnInstantiation().getArgument(0)
    }
  }

  /**
   * A script or iframe `src` attribute, viewed as a `ScriptUrlSink`.
   */
  class SrcAttributeUrlSink extends ScriptUrlSink, DataFlow::ValueNode {
    SrcAttributeUrlSink() {
      exists(DOM::AttributeDefinition attr, string eltName |
        attr.getElement().getName() = eltName and
        (eltName = "script" or eltName = "iframe") and
        attr.getName() = "src" and
        this = attr.getValueNode()
      )
    }
  }
}
