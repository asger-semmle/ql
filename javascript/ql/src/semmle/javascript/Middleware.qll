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

    /**
     * Gets the local source of the router whose middleware stack is modeled by this node.
     *
     * For routers, this refers to the node itself.
     *
     * For setups that imperatively install route handlers on an existing router, this
     * refers to the router that is being modified.
     */
    abstract DataFlow::SourceNode getRouter();

    /**
     * Gets the last child of this node.
     */
    abstract Node getLastChild();

    /**
     * Gets the previous sibling of this node, that is, the router handler executing
     * before this one.
     *
     * In general there can be multiple previous siblings, forming a sibling graph,
     * but in practice there is rarely more than once.
     */
    abstract Node getPreviousSibling();

    /**
     * Gets the next sibling of this node, that is, the router handler executing
     * after this one.
     *
     * In general there can be multiple next siblings, forming a sibling graph,
     * but in practice there is rarely more than once.
     */
    final Node getNextSibling() {
      this = result.getPreviousSibling()
    }

    /**
     * Gets a child of this node, that is, a router handler that is executed
     * as part of this route handler.
     */
    final Node getAChild() {
      result = this.getLastChild().getPreviousSibling*()
    }
    
    /**
     * Gets the parent of this node, that is, the route handler that dispatches
     * requests to this one.
     */
    final Node getParent() {
      this = result.getAChild()
    }

    /**
     * Gets the path matched by this route handler, relative to its parent.
     *
     * A route handler will reject a request not matching its path.
     *
     * Defaults to the empty string, meaning any request is accepted.
     */
    string getPath() {
      result = ""
    }

    /**
     * Normalizes a path so multiple paths can be joined by concatenation.
     *
     * In particular, this ensures we don't get duplicate `//` path separators.
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
      result = normalizePath(this.getPath())
      or
      not exists(this.getPath()) and
      result = ""
    }

    /**
     * Gets the path handled by this node, relative to the root node.
     */
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

    /**
     * Gets the request method matched by this route handler, or `*` if all
     * request methods are matched.
     *
     * The route handler will reject requests whose request method does not match.
     *
     * Defaults to `*`.
     */
    string getRequestMethod() {
      result = "*"
    }

    /**
     * Gets the request method matched by this router handler and its parents.
     */
    final string getAbsoluteRequestMethod() {
      isRoot() and result = getRequestMethod()
      or
      result = intersectRequestMethodFilters(getParent().getRequestMethod(), getRequestMethod())
    }

    /**
     * Holds if this has no parent.
     */
    final predicate isRoot() {
      not exists(getParent())
    }

    /**
     * Holds if this is part of a tree-shaped middleware stack, which is the common case.
     */
    final predicate isTree() {
      isRoot()
      or
      strictcount(getParent()) = 1 and
      getParent().isTree()
    }

    /**
     * Holds if this handler is preceded by `guard` in the middleware stack.
     *
     * That is, any request seen by this handler is known to have gone through `guard` first.
     */
    final predicate isGuardedBy(Node guard) {
      getParent*().getPreviousSibling+().getAChild*() = guard and
      getAbsolutePath() = guard.getAbsolutePath() + any(string s) and
      exists(intersectRequestMethodFilters(getAbsoluteRequestMethod(), guard.getAbsoluteRequestMethod()))
    }
  }

  /**
   * Gets the intersection of two request method filters.
   */
  bindingset[method1, method2]
  private string intersectRequestMethodFilters(string method1, string method2) {
    method1 = method2 and result = method1
    or
    method1 = "*" and result = method2
    or
    method2 = "*" and result = method1
  }

  /**
   * A middleware node with an indexed list of children.
   *
   * For example, a route setup `app.get("/", handler1, handler2, ...)` has a list of
   * children derived from its argument list.
   */
  private abstract class SequenceNode extends Node {
    /**
     * Gets the `n`th middleware function installed at this point.
     */
    abstract DataFlow::Node getMiddleware(int n);

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

    override final Node getLastChild() {
      result = getMiddleware(getNumMiddleware() - 1)
    }
  }

  /**
   * An argument in a sequence node.
   */
  private class SequenceElement extends Node {
    SequenceNode parent;
    int index;

    SequenceElement() {
      this = parent.getMiddleware(index)
    }

    override DataFlow::SourceNode getRouter() {
      result = parent.getRouter()
    }
    
    override Node getPreviousSibling() {
      result = parent.getMiddleware(index - 1)
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
   * An installation of one or more route handlers on a router.
   *
   * The router handler arguments are the children of this node.
   */
  abstract class Setup extends SequenceNode {
    override final Node getPreviousSibling() {
      result.getControlFlowNode() = any(SetupTracking tr).getLastSideEffect(getControlFlowNode().getAPredecessor(), getRouter())
    }
  }

  /**
   * A router, that is, a collection of route handlers with associated paths and request methods.
   */
  class Router extends Node {
    Router() {
      this = any(Node node).getRouter()
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
  abstract class RouteCombinator extends SequenceNode {
    override DataFlow::SourceNode getRouter() {
      result = this
    }

    override Middleware::Node getPreviousSibling() {
      none()
    }
  }

  /**
   * An array literal passed to a route setup.
   */
  private class ArrayRouteCombinator extends Middleware::RouteCombinator, DataFlow::ArrayCreationNode {
    ArrayRouteCombinator() {
      this.flowsTo(any(Node node))
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
