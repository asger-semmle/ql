/**
 * Provides generic concepts for modelling the middleware stack of a web application.
 */
import javascript
import semmle.javascript.EffectTracking
import semmle.javascript.frameworks.ExpressMiddleware // imported from here to avoid empty recursion error

module Middleware {
  /**
   * An effect-tracking configuration, tracking installations of route handlers on a router.
   */
  class SetupTracking extends EffectTracking::Configuration {
    SetupTracking() { this = "MiddlewareSetup" }
  
    override predicate isTrackedSideEffect(ControlFlowNode loc, DataFlow::SourceNode value) {
      exists (Setup setup |
        loc = setup.getControlFlowNode() and
        value = setup.getRouter())
    }
  }

  /**
   * A node in a web application's middleware stack model.
   *
   * A node very loosely represents a thing that can handle requests.
   * Incoming requests come from the parent and will be routed to the children,
   * in order of first to last.
   */
  abstract class Node extends DataFlow::Node {
    final ControlFlowNode getControlFlowNode() {
      result = getAstNode()
    }

    abstract DataFlow::SourceNode getRouter();
    
    Setup getSetup() {
      this = result
      or
      this = result.getAMiddleware()
    }

    abstract Node getLastChild();
    
    abstract Node getPreviousSibling();
    
    final Node getNextSibling() {
      this = result.getPreviousSibling()
    }
    
    final Node getAChild() {
      result = this.getLastChild().getPreviousSibling*()
    }
    
    final Node getParent() {
      this = result.getAChild()
    }

    /**
     * Holds if the requests routed to this middleware node are known to have gone through
     * the `guard` middleware first.
     */
    final predicate isGuardedBy(Node guard) {
      getParent*().getPreviousSibling+().getAChild*() = guard and
      getAbsolutePath() = guard.getAbsolutePath() + any(string s) and
      getSetup().handlesSameRequestMethodAs(guard.getSetup())
    }
    
    /**
     * Normalizes a path so multiple paths can be joined by concatenation.
     *
     * In particular, this ensures that non-empty paths end with a slash.
     */
    bindingset[str]
    private string normalizePath(string str) {
      if str = "/" or str = "" then
        result = ""
      else if str = any(string s) + "/" then
        result = str
      else
        result = str + "/"
    }

    /**
     * Gets the path handled by this node, relative to its parent.
     */
    private string getRelativePath() {
      result = normalizePath(this.(Setup).getPath())
      or
      not exists(this.(Setup).getPath()) and
      result = ""
    }

    final string getAbsolutePath() {
      isTree() and
      (
        result = getParent().getAbsolutePath() + getRelativePath()
        or
        not exists(getParent()) and
        result = getRelativePath()
      )
      or
      // If there are multiple parents, use our best approximation: the absolute paths of any of the parents
      not isTree() and
      result = getParent().getAbsolutePath()
    }
    
    final predicate isRoot() {
      not exists(getParent())
    }
    
    final predicate isTree() {
      isRoot()
      or
      strictcount(getParent()) = 1 and
      getParent().isTree()
    }
  }

  /**
   * An installation of one or more route handlers on a router.
   *
   * The router handler arguments are the children of this node.
   */
  abstract class Setup extends Node {
    /**
     * Gets the `n`th middleware function installed at this point.
     */
    abstract DataFlow::Node getMiddleware(int n);

    /**
     * Gets the path handled by this route, if it can be determined.
     */
    abstract string getPath();

    /**
     * Gets the request method handled by this route, or "*" if all methods are handled.
     */
    abstract string getRequestMethod();
  
    /**
     * Gets any of the middleware functions installed at this point.
     */
    final DataFlow::Node getAMiddleware() { result = getMiddleware(_) }
    
    final int getNumMiddleware() {
      result = count(getAMiddleware())
    }
    
    final DataFlow::Node getLastMiddleware() {
      result = getMiddleware(getNumMiddleware() - 1)
    }
    
    bindingset[other]
    final predicate handlesSameRequestMethodAs(Setup other) {
      getRequestMethod() = other.getRequestMethod() or
      getRequestMethod() = "*" or
      other.getRequestMethod() = "*"
    }

    override final Node getLastChild() {
      result = getMiddleware(getNumMiddleware() - 1)
    }

    override final Node getPreviousSibling() {
      result.getControlFlowNode() = any(SetupTracking tr).getLastSideEffect(getControlFlowNode().getAPredecessor(), getRouter())
    }
  }

  /**
   * An argument to a route setup, referring to a route handler.
   */
  class SetupArgument extends Node {
    Setup setup;
    int index;

    SetupArgument() {
      this = setup.getMiddleware(index)
    }

    override DataFlow::SourceNode getRouter() {
      result = setup.getRouter()
    }
    
    override Node getPreviousSibling() {
      result = setup.getMiddleware(index - 1)
    }
    
    override Node getLastChild() {
      result != this and
      (
        result.(DataFlow::SourceNode).flowsTo(this)
        or
        result.(DataFlow::TrackedNode).flowsTo(this)
      )
    }
  }

  /**
   * A router, that is, a collection of route handlers with associated paths and request methods.
   */
  class Router extends Node {
    Router() {
      this = any(Setup setup).getRouter()
    }

    override DataFlow::SourceNode getRouter() {
      result = this
    }
    
    override Node getPreviousSibling() {
      none()
    }
    
    override Node getLastChild() {
      result.(Setup).getControlFlowNode() = any(SetupTracking tr).getLastSideEffect(this.getContainer().getExit(), this)
    }
  }

  /**
   * A functionally defined router, as opposed to routers built up imperatively by adding router handlers on them.
   *
   * For example, an array of route handlers can in some frameworks be used as a route handler itself.
   * In this case, an array literal `[r1, r2]` would be considered a route combinator, with `r1` and `r2` as
   * its children.
   *
   * A route combinator is a `Setup` with themselves as the router.
   */
  abstract class RouteCombinator extends Setup {
    override DataFlow::SourceNode getRouter() {
      result = this
    }

    override string getPath() {
      result = ""
    }

    override string getRequestMethod() {
      result = "*"
    }
  }

  /**
   * An array literal passed to a route setup.
   */
  class ArrayRouteCombinator extends Middleware::RouteCombinator, DataFlow::ArrayCreationNode {
    ArrayRouteCombinator() {
      this.flowsTo(any(Setup setup).getAMiddleware())
    }
  
    override DataFlow::Node getMiddleware(int n) {
      result = getElement(n)
    }
  }

  /**
   * A call to a function that contains middleware installations.
   */
  class SubSetup extends Middleware::Node, DataFlow::InvokeNode {
    DataFlow::SourceNode router;

    SubSetup() {
      any(SetupTracking tr).calleeHasSideEffects(this, router)
    }

    override DataFlow::SourceNode getRouter() {
      result = router
    }

    override Middleware::Node getLastChild() {
      exists (DataFlow::SourceNode subrouter, ControlFlowNode loc |
        loc = any(SetupTracking tr).getLastSideEffectInCallee(this, router, subrouter) and
        if subrouter = router then
          result.getControlFlowNode() = loc
        else
          result = subrouter)
    }

    override Middleware::Node getPreviousSibling() {
      result.getControlFlowNode() = any(SetupTracking tr).getLastSideEffect(getControlFlowNode().getAPredecessor(), router)
    }
  }
}
