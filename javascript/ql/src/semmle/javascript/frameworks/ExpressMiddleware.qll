import javascript
import semmle.javascript.Middleware

/**
 * An Express route setup as a Middleware setup.
 */
private class ExpressMiddlewareSetup extends Middleware::Setup {
  Express::RouteSetup setup;

  ExpressMiddlewareSetup() {
    this = setup.flow()
  }

  override DataFlow::SourceNode getRouter() {
    result = setup.getReceiver().flow().getALocalSource()
  }

  override DataFlow::Node getMiddleware(int n) {
    result = setup.getRouteHandlerExpr(n).flow()
  }

  override string getPath() {
    result = setup.getPath()
  }
  
  override string getRequestMethod() {
    result = setup.getRequestMethod()
    or
    setup.handlesAllRequestMethods() and
    result = "*"
  }
}

private class ArrayRouteCombinator extends Middleware::RouteCombinator, DataFlow::ArrayCreationNode {
  ArrayRouteCombinator() {
    this.flowsTo(any(Middleware::Setup setup).getAMiddleware())
  }

  override DataFlow::Node getMiddleware(int n) {
    result = getElement(n)
  }
}
