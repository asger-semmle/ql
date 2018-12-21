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
      UnixPath toNormalized() {
        result.isNormalized() and
        result.getRelativeness() = this.getRelativeness()
      }

      /** Gets the path label with normalized flag set to true. */
      UnixPath toNonNormalized() {
        result.isNonNormalized() and
        result.getRelativeness() = this.getRelativeness()
      }

      /** Gets the path label with absolute flag set to true. */
      UnixPath toAbsolute() {
        result.isAbsolute() and
        result.getNormalization() = this.getNormalization()
      }

      /** Gets the path label with absolute flag set to true. */
      UnixPath toRelative() {
        result.isRelative() and
        result.getNormalization() = this.getNormalization()
      }
      
      /** Holds if this path may contain `../` components. */
      predicate canContainDotDotSlash() {
        // Absolute normalized path is the only combination that cannot contain `../`. 
        not (isNormalized() and isAbsolute())
      }

      /**
       * Gets an uncapitalized description of this path, such as "an absolute path".
       */
      string describe() {
        isRelative() and
        result = "a path containing '../'"
        or
        not isRelative() and
        result = "an absolute path"
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
      guard instanceof StartsWithDotDotSanitizer or
      guard instanceof StartsWithDirSanitizer or
      guard instanceof IsAbsoluteSanitizer
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
    predicate isTaintedPathStep(DataFlow::Node src, DataFlow::Node dst,  DataFlow::FlowLabel srclabel, Label::UnixPath dstlabel) {
      exists (NormalizingPathCall call |
        src = call.getInput() and
        dst = call.getOutput() and
        dstlabel = Label::toUnixPath(srclabel).toNormalized()
      )
      or
      exists (ResolvingPathCall call |
        src = call.getInput() and
        dst = call.getOutput() and
        srclabel = anyLabel() and
        dstlabel.isAbsolute() and
        dstlabel.isNormalized()
      )
      or
      // Prefixing a string with anything other than `/` makes it relative.
      // If the prefix does start with a `/`, the prefix is likely the intended root directory so `../` is the only
      // viable attack vector afterwards.
      exists (DataFlow::Node operator, int n | StringConcatenation::taintStep(src, dst, operator, n) |
        n > 0 and
        Label::toUnixPath(srclabel).canContainDotDotSlash() and
        dstlabel.isRelative() and   // The path may be absolute, but the attacker only controls a relative path in it.
        dstlabel.isNonNormalized()  // The ../ is no longer at the beginning of the string.
        or
        // use ordinary taint flow for the first operand
        n = 0 and
        (
          srclabel != DataFlow::FlowLabel::data() and
          dstlabel = srclabel
          or
          srclabel = DataFlow::FlowLabel::data() and
          dstlabel = DataFlow::FlowLabel::taint()
        )
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
   * A call that converts a path to an absolute normalized path.
   */
  class ResolvingPathCall extends DataFlow::CallNode {
    DataFlow::Node input;
    DataFlow::Node output;

    ResolvingPathCall() {
      this = DataFlow::moduleMember("path", "resolve").getACall() and
      input = getAnArgument() and
      output = this
      or
      this = DataFlow::moduleMember("fs", "realpathSync").getACall() and
      input = getArgument(0) and
      output = this
      or
      this = DataFlow::moduleMember("fs", "realpath").getACall() and
      input = getArgument(0) and
      output = getCallback(1).getParameter(1)
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
      this = startsWith and
      startsWith.getSubstring().asExpr().getStringValue() + any(string s) = "../"
    }

    override predicate sanitizes(boolean outcome, Expr e, DataFlow::FlowLabel label) {
      // Sanitize in the false case for:
      //   .startsWith(".")
      //   .startsWith("..")
      //   .startsWith("../")
      outcome = startsWith.getPolarity().booleanNot() and
      e = startsWith.getBaseString().asExpr() and
      label.(Label::UnixPath).isNormalized() and
      label.(Label::UnixPath).isRelative()
    }
  }
 
  /**
   * A check of form `x.startsWith(dir)` that sanitizes normalized absolute paths, since it is then
   * known to be in a subdirectory of `dir`. 
   */
  class StartsWithDirSanitizer extends TaintTracking::LabeledSanitizerGuardNode {
    StartsWithCheck startsWith;

    StartsWithDirSanitizer() {
      this = startsWith and
      // do not confuse this with a simple isAbsolute() check
      not startsWith.getSubstring().asExpr().getStringValue() = "/"
    }

    override predicate sanitizes(boolean outcome, Expr e, DataFlow::FlowLabel label) {
      outcome = startsWith.getPolarity() and
      e = startsWith.getBaseString().asExpr() and
      label.(Label::UnixPath).isAbsolute() and
      label.(Label::UnixPath).isNormalized()
    }
  }

  /**
   * A call to `path.isAbsolute` as a sanitizer for relative paths in true branch,
   * and a sanitizer for absolute paths in the false branch.
   */
  class IsAbsoluteSanitizer extends TaintTracking::LabeledSanitizerGuardNode {
    DataFlow::Node operand;
    boolean polarity;

    IsAbsoluteSanitizer() {
      exists (DataFlow::CallNode call | this = call |
        call = DataFlow::moduleMember("path", "isAbsolute").getACall() and
        operand = call.getArgument(0) and
        polarity = true)
      or
      exists (StartsWithCheck startsWith | this = startsWith |
        startsWith.getSubstring().asExpr().getStringValue() = "/" + any(string s) and
        operand = startsWith.getBaseString() and
        polarity = startsWith.getPolarity())
    }

    override predicate sanitizes(boolean outcome, Expr e, DataFlow::FlowLabel label) {
      e = operand.asExpr() and
      (
        outcome = polarity and label.(Label::UnixPath).isRelative()
        or
        outcome = polarity.booleanNot() and label.(Label::UnixPath).isAbsolute()
      )
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
      this = any(FileSystemAccess fs).getAPathArgument() and
      not this = any(ResolvingPathCall call).getInput()
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
}

/** DEPRECATED: Use `TaintedPath::Source` instead. */
deprecated class TaintedPathSource = TaintedPath::Source;

/** DEPRECATED: Use `TaintedPath::Sink` instead. */
deprecated class TaintedPathSink = TaintedPath::Sink;

/** DEPRECATED: Use `TaintedPath::Sanitizer` instead. */
deprecated class TaintedPathSanitizer = TaintedPath::Sanitizer;

/** DEPRECATED: Use `TaintedPath::Configuration` instead. */
deprecated class TaintedPathTrackingConfig = TaintedPath::Configuration;
