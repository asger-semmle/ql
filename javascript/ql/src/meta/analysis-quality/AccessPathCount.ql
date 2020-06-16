/**
 * @name Access path count
 * @description The number of access paths. Lower is generally better,
 *      for a given number of aliases.
 * @kind metric
 * @metricType project
 * @metricAggregate sum
 * @tags meta
 * @id js/meta/aliased-accesses
 */

import javascript
import AccessPathQuality

select projectRoot(),
  count(AccessPath::Root root, string path | exists(relevantReferenceTo(root, path)))
