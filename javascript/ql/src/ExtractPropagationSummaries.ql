/**
 * @name Extract propagation summaries
 * @description Extracts propagation summaries, that is, tuples of the form `(in, out)` representing
 *              the fact that data flowing into a definition of `in` flows out of a use of `out`.
 * @kind propagation-summary
 * @id js/propagation-summary-extraction
 */

import ApiGraphs

from LocalApiGraph::UseNode i, LocalApiGraph::DefNode o
where
  exists(LocalApiGraph::Node base |
    i = base.getParameter(_).getASuccessor*() and
    o = base.getReturn().getASuccessor*()
  ) and
  i.flowsTo(o.asDataFlowNode()) and
  // only extract summaries for modules defined in this database
  o = LocalApiGraph::moduleDefinition(_).getASuccessor*()
select "propagationSummary", i, o
