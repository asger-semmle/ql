/**
 * @name Access path aliases
 * @description The number of nodes for which we found one or more
 *     aliases through an access path. Higher is generally better.
 * @kind metric
 * @metricType project
 * @metricAggregate sum
 * @tags meta
 * @id js/meta/aliased-accesses
 */

import javascript
import AccessPathQuality

select projectRoot(), count(DataFlow::Node node | nodeHasAliases(node))
