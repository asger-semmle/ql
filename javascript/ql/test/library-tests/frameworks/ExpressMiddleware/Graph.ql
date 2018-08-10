import javascript
import semmle.javascript.frameworks.ExpressMiddleware

predicate edge(Middleware::Node source, Middleware::Node dest, string kind) {
  dest = source.getLastChild() and kind = "last-child"
  or
  dest = source.getPreviousSibling() and kind = "prev-sibling"
}

from Middleware::Node src, Middleware::Node dst, string kind
where edge(src, dst, kind)
select src, kind, dst
