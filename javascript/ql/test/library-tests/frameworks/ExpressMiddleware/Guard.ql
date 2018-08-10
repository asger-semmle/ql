import javascript
import semmle.javascript.frameworks.ExpressMiddleware

class MakeMiddleware extends DataFlow::InvokeNode {
  MakeMiddleware() {
    getCalleeName() = "makeMiddleware"
  }

  int getOrder() {
    result = getArgument(0).asExpr().getIntValue()
  }
  
  Middleware::Node asMiddleware() {
    result = this
  }

  MakeMiddleware getPrevious() {
    result.getOrder() = getOrder() - 1
  }
  
  string getError() {
    not exists(asMiddleware()) and
    result = "Not a middleware node"
    or
    exists(getPrevious()) and
    not asMiddleware().isGuardedBy(getPrevious().asMiddleware()) and
    result = "Middleware " + getOrder() + " is not guarded by " + getPrevious().getOrder()
    or
    exists (MakeMiddleware guard |
      asMiddleware().isGuardedBy(guard.asMiddleware()) and
      guard.getOrder() > getOrder() and
      result = "Middleware " + getOrder() + " is spuriously guarded by " +  guard.getOrder()
    )
  }
}

from MakeMiddleware middleware
select middleware, middleware.getError()
