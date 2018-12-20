/**
 * @name Uncontrolled data used in path expression
 * @description Accessing paths influenced by users can allow an attacker to access
 *              unexpected resources.
 * @kind path-problem
 * @problem.severity error
 * @precision high
 * @id js/path-injection
 * @tags security
 *       external/cwe/cwe-022
 *       external/cwe/cwe-023
 *       external/cwe/cwe-036
 *       external/cwe/cwe-073
 *       external/cwe/cwe-099
 */

import javascript
import semmle.javascript.security.dataflow.TaintedPath::TaintedPath
import DataFlow::PathGraph

string getPathDescription(DataFlow::FlowLabel label) {
  label = DataFlow::FlowLabel::dataOrTaint() and
  result = "." // fully user-controlled, no further explanation needed
  or
  result =", which could be " + label.(Label::UnixPath).describe() + "."
}

from Configuration cfg, DataFlow::PathNode source, DataFlow::PathNode sink
where cfg.hasFlowPath(source, sink)
select sink.getNode(), source, sink, "This path depends on $@" + getPathDescription(sink.getEndLabel()),
       source.getNode(), "a user-provided value"
