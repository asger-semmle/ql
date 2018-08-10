import javascript
import semmle.javascript.frameworks.ExpressMiddleware

from Middleware::Node node, Middleware::Node guard
where node.isGuardedBy(guard)
select node, guard

