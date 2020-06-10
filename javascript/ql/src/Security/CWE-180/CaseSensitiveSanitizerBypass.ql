/**
 * @name Case-sensitive sanitizer bypass
 * @description Validating HTML tag names or URL schemes without handling mixed-case inputs
 *              can lead to cross-site scripting vulnerabilities.
 * @kind path-problem
 * @severity warning
 * @precision high
 * @id js/case-sensitive-sanitizer-bypass
 * @tags correctness
 *       security
 */
import javascript
import semmle.javascript.PackageExports
import DataFlow::PathGraph

string getAMemberString(InclusionTest test) {
  result = test.getContainerNode().getALocalSource().(DataFlow::ArrayCreationNode).getAnElement().getStringValue()
}

class Configuration extends TaintTracking::Configuration {
  Configuration() { this = "CaseSensitiveSanitizerBypass" } 

  override predicate isSource(DataFlow::Node node) {
    node instanceof RemoteFlowSource
    or
    node = DOM::locationSource()
    or
    exists(DataFlow::ParameterNode param, string nameRex |
      param = getAValueExportedBy(_).(DataFlow::FunctionNode).getAParameter() and
      nameRex = "(?i).*(html|markdown|markup|text|content|title|label|legend|tooltip|url|uri).*"
    |
      param.getName().regexpMatch(nameRex) and node = param
      or
      node = param.getAPropertyRead(any(string s | s.regexpMatch(nameRex)))
    )
  }

  override predicate isSink(DataFlow::Node node) {
    exists(InclusionTest test | node = test.getContainedNode() |
      getAMemberString(test) = ["script", "SCRIPT", "javascript:"] and
      // Exclude tests not related to security
      not getAMemberString(test) = ["p", "P", "b", "B", "i", "I", "https:"]
    )
    or
    exists(StringOps::StartsWith startsWith |
      startsWith.getSubstring().getStringValue() = ["<script", "<SCRIPT", "javascript:"] and
      node = startsWith.getBaseString()
    )
  }

  override predicate isSanitizer(DataFlow::Node node) {
    // Treat toLowerCase and friends as sanitizers.
    // Use a broad pattern to include things like toLocaleLowerCase and _.lowerCase.
    node.(DataFlow::CallNode).getCalleeName().regexpMatch("(?i).*(lower|upper|title|snake|camel|kebab|normalized?)case")
  }
}

from Configuration cfg, DataFlow::PathNode source, DataFlow::PathNode sink
where cfg.hasFlowPath(source, sink)
select sink, source, sink, "This check can be bypasssed by mixed-case inputs from $@.", source.getNode(), "here"
