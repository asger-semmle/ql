/**
 * Provides a taint tracking configuration for reasoning about tainted-path
 * vulnerabilities.
 */

import javascript

module TaintedPath {
  /**
   * A data flow source for tainted-path vulnerabilities.
   */
  abstract class Source extends DataFlow::Node { }

  /**
   * A data flow sink for tainted-path vulnerabilities.
   */
  abstract class Sink extends DataFlow::Node { }

  /**
   * A sanitizer for tainted-path vulnerabilities.
   */
  abstract class Sanitizer extends DataFlow::Node { }

  module Label {
    /**
     * String indicating if a path is normalized, that is, whether internal `../` components
     * have been removed.
     */
    class Normalization extends string {
      Normalization() { this = "normalized" or this = "raw" }
    }

    /**
     * String indicating if a path is relative or absolute.
     */
    class Relativeness extends string {
      Relativeness() { this = "relative" or this = "absolute" }
    }

    /**
     * A flow label representing a Unix path.
     *
     * There are currently four flow labels, representing the different combinations of
     * normalization and absoluteness.
     */
    class UnixPath extends DataFlow::FlowLabel {
      Normalization normalization;
      Relativeness relativeness;

      UnixPath() {
        this = normalization + "-" + relativeness + "-unix-path"
      }

      /** Gets a string indicating whether this path is normalized. */
      Normalization getNormalization() { result = normalization }

      /** Gets a string indicating whether this path is relative. */
      Relativeness getRelativeness() { result = relativeness }

      /** Holds if this path is normalized. */
      predicate isNormalized() { normalization = "normalized" }

      /** Holds if this path is not normalized. */
      predicate isNonNormalized() { normalization = "raw" }

      /** Holds if this path is relative. */
      predicate isRelative() { relativeness = "relative" }

      /** Holds if this path is relative. */
      predicate isAbsolute() { relativeness = "absolute" }

      /** Gets the path label with normalized flag set to true. */
      UnixPath normalize() {
        result.isNormalized() and
        result.getRelativeness() = this.getRelativeness()
      }
    }

    /**
     * Gets the possible Unix path labels corresponding to `label`.
     *
     * A unix path label is just mapped to itself, but `data` and `taint` are assumed
     * to be fully user-controlled, and thus map to every possible unix path label.
     */
    UnixPath toUnixPath(DataFlow::FlowLabel label) {
      result = label
      or
      label = DataFlow::FlowLabel::dataOrTaint()
    }
  }

  /** Gets any flow label. */
  private DataFlow::FlowLabel anyLabel() {
    any()
  }

  /**
   * A taint-tracking configuration for reasoning about tainted-path vulnerabilities.
   */
  class Configuration extends TaintTracking::Configuration {
    Configuration() { this = "TaintedPath" }

    override predicate isSource(DataFlow::Node source) {
      source instanceof Source
    }

    override predicate isSink(DataFlow::Node sink, DataFlow::FlowLabel label) {
      sink instanceof Sink and
      label = anyLabel()
    }

    override predicate isSanitizer(DataFlow::Node node) {
      super.isSanitizer(node) or
      node instanceof Sanitizer
    }

    override predicate isSanitizerGuard(TaintTracking::SanitizerGuardNode guard) {
      guard instanceof StrongPathCheck or
      guard instanceof StartsWithDotDotSanitizer
    }

    override predicate isAdditionalFlowStep(DataFlow::Node src, DataFlow::Node dst, DataFlow::FlowLabel srclabel, DataFlow::FlowLabel dstlabel) {
      isTaintedPathStep(src, dst, srclabel, dstlabel)
    }

    override predicate isOmittedTaintStep(DataFlow::Node src, DataFlow::Node dst) {
      isTaintedPathStep(src, dst, _, _)
    }

    /**
     * Holds if we should include a step from `src -> dst` with labels `srclabel -> dstlabel`, and the
     * standard taint step `src -> dst` should be suppresesd.
     */
    predicate isTaintedPathStep(DataFlow::Node src, DataFlow::Node dst,  DataFlow::FlowLabel srclabel, DataFlow::FlowLabel dstlabel) {
      exists (NormalizingPathCall call |
        src = call.getInput() and
        dst = call.getOutput() and
        dstlabel = Label::toUnixPath(srclabel).normalize()
      )
    }
  }

  /**
   * A call that normalizes a path.
   */
  class NormalizingPathCall extends DataFlow::CallNode {
    DataFlow::Node input;
    DataFlow::Node output;

    NormalizingPathCall() {
      this = DataFlow::moduleMember("path", "normalize").getACall() and
      input = getArgument(0) and
      output = this
    }

    /**
     * Gets the input path to be normalized.
     */
    DataFlow::Node getInput() {
      result = input
    }

    /**
     * Gets the normalized path.
     */
    DataFlow::Node getOutput() {
      result = output
    }
  }

  /**
   * A check of form `x.startsWith("../")` or similar.
   *
   * This is relevant for paths that are known to be normalized.
   */
  class StartsWithDotDotSanitizer extends TaintTracking::LabeledSanitizerGuardNode {
    StartsWithCheck startsWith;

    StartsWithDotDotSanitizer() {
      this = startsWith
    }

    override predicate sanitizes(boolean outcome, Expr e) {
      // Sanitize in the false case for:
      //   .startsWith(".")
      //   .startsWith("..")
      //   .startsWith("../")
      startsWith.getSubstring().asExpr().getStringValue() + any(string s) = "../" and
      outcome = startsWith.getPolarity().booleanNot() and
      e = startsWith.getBaseString().asExpr()
    }

    override Label::UnixPath getALabel() {
      result.isNormalized() and result.isRelative()
    }
  }

  /**
   * A call to `path.isAbsolute` as a sanitizer for absolute paths.
   */
  class IsAbsoluteSanitizer extends TaintTracking::LabeledSanitizerGuardNode, DataFlow::CallNode {
    IsAbsoluteSanitizer() {
      this = DataFlow::moduleMember("path", "isAbsolute").getACall()
    }

    override predicate sanitizes(boolean outcome, Expr e) {
      // Sanitize absolute paths in the false case.
      outcome = false and
      e = getArgument(0).asExpr()
      // TODO: We should also sanitize relative paths in the true case, but this is not currently possible.
    }

    override Label::UnixPath getALabel() {
      result.isAbsolute()
    }
  }

  /**
   * A source of remote user input, considered as a flow source for
   * tainted-path vulnerabilities.
   */
  class RemoteFlowSourceAsSource extends Source {
    RemoteFlowSourceAsSource() { this instanceof RemoteFlowSource }
  }

  /**
   * An expression whose value is interpreted as a path to a module, making it
   * a data flow sink for tainted-path vulnerabilities.
   */
  class ModulePathSink extends Sink, DataFlow::ValueNode {
    ModulePathSink() {
      astNode = any(Require rq).getArgument(0) or
      astNode = any(ExternalModuleReference rq).getExpression() or
      astNode = any(AMDModuleDefinition amd).getDependencies()
    }
  }

  /**
   * A path argument to a file system access.
   */
  class FsPathSink extends Sink, DataFlow::ValueNode {
    FsPathSink() {
      this = any(FileSystemAccess fs).getAPathArgument()
    }
  }

  /**
   * A path argument to the Express `res.render` method.
   */
  class ExpressRenderSink extends Sink, DataFlow::ValueNode {
    ExpressRenderSink() {
      exists (MethodCallExpr mce |
        Express::isResponse(mce.getReceiver()) and
        mce.getMethodName() = "render" and
        astNode = mce.getArgument(0)
      )
    }
  }

  /**
   * A `templateUrl` member of an AngularJS directive.
   */
  class AngularJSTemplateUrlSink extends Sink, DataFlow::ValueNode {
    AngularJSTemplateUrlSink() {
      this = any(AngularJS::CustomDirective d).getMember("templateUrl")
    }
  }

  /**
   * Holds if `check` evaluating to `outcome` is not sufficient to sanitize `path`.
   */
  predicate weakCheck(Expr check, boolean outcome, VarAccess path) {
    // `path.startsWith` and equivalent
    path = check.flow().(StartsWithCheck).getBaseString().asExpr() and
    (outcome = true or outcome = false)
    or
    // `path.endsWith`, `fs.existsSync(path)`
    exists (Expr base, string m | check.(MethodCallExpr).calls(base, m) |
      path = base and
      m = "endsWith"
      or
      path = check.(MethodCallExpr).getArgument(0) and
      m.regexpMatch("exists(Sync)?")
    ) and
    (outcome = true or outcome = false)
    or
    // `path.indexOf` comparisons
    check.(Comparison).getAnOperand().(MethodCallExpr).calls(path, "indexOf") and
    (outcome = true or outcome = false)
    or
    // `path != null`, `path != undefined`, `path != "somestring"`
    exists (EqualityTest eq, Expr op |
      eq = check and eq.hasOperands(path, op) and outcome = eq.getPolarity().booleanNot() |
      op instanceof NullLiteral or
      op instanceof SyntacticConstants::UndefinedConstant or
      exists(op.getStringValue())
    )
    or
    // `path`
    check = path and
    (outcome = true or outcome = false)
  }

  /**
   * A conditional involving the path, that is not considered to be a weak check.
   */
  class StrongPathCheck extends TaintTracking::SanitizerGuardNode {
    VarAccess path;
    boolean sanitizedOutcome;

    StrongPathCheck() {
      exists (ConditionGuardNode cgg | asExpr() = cgg.getTest() |
        asExpr() = path.getParentExpr*() and
        path = any(SsaVariable v).getAUse() and
        (sanitizedOutcome = true or sanitizedOutcome = false) and
        not weakCheck(asExpr(), sanitizedOutcome, path)
      )
    }

    override predicate sanitizes(boolean outcome, Expr e) {
      path = e and
      outcome = sanitizedOutcome
    }
  }
}

/** DEPRECATED: Use `TaintedPath::Source` instead. */
deprecated class TaintedPathSource = TaintedPath::Source;

/** DEPRECATED: Use `TaintedPath::Sink` instead. */
deprecated class TaintedPathSink = TaintedPath::Sink;

/** DEPRECATED: Use `TaintedPath::Sanitizer` instead. */
deprecated class TaintedPathSanitizer = TaintedPath::Sanitizer;

/** DEPRECATED: Use `TaintedPath::Configuration` instead. */
deprecated class TaintedPathTrackingConfig = TaintedPath::Configuration;
