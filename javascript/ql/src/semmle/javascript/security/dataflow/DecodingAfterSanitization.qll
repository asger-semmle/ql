import javascript

module DecodingAfterSanitization {
  /**
   * A type of sanitization, such as HTML sanitization or filename sanitization.
   */
  abstract class SanitizationKind extends string {
    bindingset[this]
    SanitizationKind() { any() }

    abstract predicate isSanitizer(DataFlow::Node sanitizer, DataFlow::Node output);
    abstract predicate isUnsafeDecoding(DecodingKind kind);
  }

  /**
   * A kind of decoding, such as JSON parsing or URI decoding.
   */
  abstract class DecodingKind extends string {
    bindingset[this]
    DecodingKind() { any() }

    abstract predicate isDecoderInput(DataFlow::Node node);
  }

  /**
   * A taint-tracking configuration for reasoning about XSS.
   */
  class Configuration extends TaintTracking::Configuration {
    Configuration() { this = "DecodingAfterSanitization" }

    override predicate isSource(DataFlow::Node source) {
      any(SanitizationKind kind).isSanitizer(_, source)
    }

    override predicate isSink(DataFlow::Node sink) {
      any(DecodingKind kind).isDecoderInput(sink)
    }
  }

  /**
   * A sanitizer defined by a guard.
   */
  class GuardSanitization extends SanitizationKind {
    GuardSanitization() { this = "GuardSanitization" }
    
    override predicate isSanitizer(DataFlow::Node sanitizer, DataFlow::Node output) {
      sanitizer.(TaintTracking::SanitizerGuardNode).blocks(output)
    }

    override predicate isUnsafeDecoding(DecodingKind kind) {
      any()
    }
  }

  /**
   * A guard of form `x.includes(y)` as a means to sanitize `x` in the false case.
   *
   * Decoding typically not remove the presence of a dangerous substring, so the 'then'
   * case should not be considered sanitized.
   */
  class StringContainmentGuard extends TaintTracking::SanitizerGuardNode, DataFlow::MethodCallNode {
    StringContainmentGuard() {
      getMethodName() = "includes" or
      getMethodName() = "startsWith" or
      getMethodName() = "endsWith"
    }

    override predicate sanitizes(boolean outcome, Expr e) {
      outcome = false and
      e = getReceiver().asExpr()
    }
  }

  predicate getIntComparison(Comparison compare, Expr arg, string operator, int value) {
    arg = compare.getLeftOperand() and
    operator = compare.getOperator() and
    value = compare.getRightOperand().getIntValue()
    or
    arg = compare.getRightOperand() and
    operator = commute(compare.getOperator()) and
    value = compare.getLeftOperand().getIntValue()
  }

  string commute(string operator) {
    if operator = "==" or operator = "===" or operator = "!=" or operator = "!==" then
      result = operator
    else if operator = "<" then
      result = ">"
    else if operator = "<=" then
      result = ">="
    else if operator = ">" then
      result = "<"
    else if operator = ">=" then
      result = "<="
    else
      none()
  }

  predicate isSanitizingSearchString(Expr e) {
    exists (string value | value = e.getStringValue() |
      value.regexpMatch("[./\\\\]+") and value != "." or // Search for relative/absolute path, such as `../`
      value.regexpMatch("</?[a-zA-Z]+/?>?") or // Search for specific HTML tag, such as `<script`
      value.regexpMatch("[<>`'\"]") // Search for single meta character
    )
  }

  predicate isSanitizingRegExp(RegExpLiteral literal) {
    literal.isGlobal() and // "Improper sanitization" query will check for missing global flag, so require it here.
    (
      // Search for relative/absoute path.
      forex(RegExpConstant const | const = literal.getRoot().getAChild*() | const.getValue().regexpMatch("[./\\\\]"))
      and not literal.getRoot().(RegExpConstant).getValue() = "."
      or
      // Search for specific HTML element (any global regexp starting with `<` at the top-level term)
      exists (RegExpSequence seq | seq = literal.getRoot() |
        seq.getChild(0).(RegExpConstant).getValue() = "<")
      or
      // Search for single meta character
      exists (RegExpCharacterClass cls | cls = literal.getRoot() |
        not cls.isInverted() and
        cls.getAChild().(RegExpConstant).getValue().regexpMatch("[<>`'\"]") and
        forall(RegExpTerm term | term = cls.getAChild() |
          term.(RegExpConstant).getValue().regexpMatch("[<>`'\"&/:]")))
    )
  }

  /**
   * A guard of form `x.indexOf(y) == z` as a means to sanitize `x`. 
   */
  class StringIndexOfGuard extends TaintTracking::SanitizerGuardNode, DataFlow::Node {
    DataFlow::MethodCallNode indexOf;
    boolean polarity;

    StringIndexOfGuard() {
      indexOf.getMethodName() = "indexOf" and
      isSanitizingSearchString(indexOf.getArgument(0).asExpr()) and
      exists (Comparison compare, Expr arg, string op, int value | this = compare.flow() |
        indexOf.flowsToExpr(arg) and
        getIntComparison(compare, arg, op, value) and

        // The comparison can either check for the absence of a substring, or the presence of a substring.
        // In the 'absent' case, we consider the value sanitized, i.e. it should not be decoded because
        // that could reintroduce the dangerous substring.
        (
          value = -1 and
          polarity = compare.(EqualityTest).getPolarity()
          or

          value >= 0 and
          polarity = compare.(EqualityTest).getPolarity().booleanNot()
          or

          if op = "<" and -1 < value or
             op = "<=" and -1 <= value or
             op = ">" and -1 > value or
             op = ">=" and -1 >= value then
             polarity = true
           else
             polarity = false
        ))
    }

    override predicate sanitizes(boolean outcome, Expr e) {
      outcome = polarity and
      e = indexOf.getReceiver().asExpr()
    }
  }

  class RegexpReplaceSanitizer extends DataFlow::MethodCallNode {
    RegexpReplaceSanitizer() {
      getMethodName() = "replace" and
      exists (Expr arg | arg = getArgument(0).asExpr() |
        isSanitizingSearchString(arg) or
        isSanitizingRegExp(arg))
    }
  }

  class RegExpReplaceSanitization extends SanitizationKind {
    RegExpReplaceSanitization() {
      this = "RegExpReplaceSanitization"
    }

    override predicate isSanitizer(DataFlow::Node sanitizer, DataFlow::Node output) {
      sanitizer = output and
      sanitizer instanceof RegexpReplaceSanitizer
    }

    override predicate isUnsafeDecoding(DecodingKind kind) {
      any()
    }
  }

  /**
   * Converts a string to kebab-case. That is, all letters become lower-case
   * and words are separated by dashes (`-`).
   *
   * For example, `getUrlPath`, `GetUrlPath`, and `GET_URL_PATH` all map to `get-url-path`.
   */
  bindingset[arg]
  private string toKebabCase(string arg) {
    result = arg
      .replaceAll("$", "")
      .replaceAll("_", "-")
      .regexpReplaceAll("([a-z])([A-Z])", "$1-$2") // getFoo => get-Foo
      .regexpReplaceAll("([A-Z])([A-Z][a-z])", "$1-$2") // HTTPServer => HTTP-Server
      .toLowerCase()
  }

  predicate isValidationCandidate(DataFlow::CallNode call) {
    exists(string callee | callee = toKebabCase(call.getCalleeName()) |
      callee.regexpMatch("(?i).*\\b(path|domain|host(name)?|html|script|(un)?safe|(in)?secure)\\b.*") and
      (
        callee.regexpMatch("(?i).*\\b(is|has|contains)\\b.*\\b(in|un)?(safe|valid|expected|correct|secure|relative|absolute|blacklist|whitelist).*")
        or
        callee.regexpMatch("(?i)(check|validat|verif|startsWith|endsWith|includes).*")
      ))
  }

  private class ValidationCall extends DataFlow::CallNode, TaintTracking::SanitizerGuardNode {
    ValidationCall() {
      isValidationCandidate(this)
    }

    override predicate sanitizes(boolean output, Expr e) {
      e = getAnArgument().asExpr() and
      (output = true or output = false)
    }
  }

  /**
   * Sanitization by calling an HTML sanitizier.
   */
  class HtmlSanitization extends SanitizationKind {
    HtmlSanitization() { this = "HtmlSanitization" }
    
    override predicate isSanitizer(DataFlow::Node sanitizer, DataFlow::Node output) {
      sanitizer = output and
      sanitizer instanceof HtmlSanitizerCall
    }

    override predicate isUnsafeDecoding(DecodingKind kind) {
      any()
    }
  }

  /**
   * Sanitization by calling a filename sanitizer.
   */
  class FilenameSanitization extends SanitizationKind {
    FilenameSanitization() { this = "FilenameSanitization" }

    override predicate isSanitizer(DataFlow::Node sanitizer, DataFlow::Node output) {
      sanitizer = output and
      sanitizer = DataFlow::moduleImport("sanitize-filename").getACall()
    }

    override predicate isUnsafeDecoding(DecodingKind kind) {
      any()
    }
  }

  private DataFlow::CallNode sqlSanitizer() {
    exists (DataFlow::SourceNode callee | result = callee.getACall() |
      callee = DataFlow::moduleMember("sqlstring", "escape") or
      callee = DataFlow::moduleMember("sqlstring", "escapeId") or
      callee = DataFlow::moduleMember("mysql", "escape") or
      callee = DataFlow::moduleMember("mysql", "escapeId"))
  }

  /**
   * Sanitization by calling a SQL sanitizer.
   */
  class SqlSanitization extends SanitizationKind {
    SqlSanitization() { this = "SqlSanitization" }

    override predicate isSanitizer(DataFlow::Node sanitizer, DataFlow::Node output) {
      sanitizer = output and
      sanitizer = sqlSanitizer()
    }

    override predicate isUnsafeDecoding(DecodingKind kind) {
      any()
    }
  }

  /**
   * Decoding by calling a JSON parser.
   */
  private class JsonParsing extends DecodingKind {
    JsonParsing() { this = "JsonParsing" }
    
    override predicate isDecoderInput(DataFlow::Node node) {
      node = any(JsonParserCall call).getInput()
    }
  }

  DataFlow::CallNode uriDecoderCall() {
    result.getCalleeName() = "decodeURI" or
    result.getCalleeName() = "decodeURIComponent" or
    exists (DataFlow::SourceNode callee | result = callee.getACall() |
      result = DataFlow::moduleMember("url", "domainToASCII") or
      result = DataFlow::moduleMember("url", "domainToUnicode") or
      result = DataFlow::moduleMember("urijs", "decode") or
      result = DataFlow::moduleMember("urijs", "decodeQuery") or
      result = DataFlow::moduleMember("urijs", "decodePathSegment") or
      result = DataFlow::moduleMember("urijs", "decodePath") or
      result = DataFlow::moduleMember("urijs", "decodeUrnPath") or
      result = DataFlow::moduleMember("urijs", "parseQuery") or
      result = DataFlow::moduleMember("uri-js", "pctDecChars") or
      result = DataFlow::moduleMember("uri-js", "unescapeComponent") or
      result = DataFlow::moduleMember("querystringify", "parse") or
      result = DataFlow::moduleMember("query-string", "parse") or
      result = DataFlow::moduleMember("query-string", "parseUrl") or
      result = DataFlow::moduleMember("querystring", "unescapeBuffer") or
      result = DataFlow::moduleMember("querystring", "unescape") or
      result = DataFlow::moduleMember("querystring", "parse") or
      result = DataFlow::moduleMember("querystring", "decode"))
  }

  /**
   * Decoding by calling a URI decoder.
   */
  class UriDecoding extends DecodingKind {
    UriDecoding() { this = "UriDecoding" }
    
    override predicate isDecoderInput(DataFlow::Node node) {
      node = uriDecoderCall().getArgument(0)
    }
  }

  /** Gets a call to a function that takes a base-64 encoded string and decodes it. */
  DataFlow::CallNode base64DecoderCall() {
    exists (DataFlow::SourceNode callee | result = callee.getACall() |
      callee = DataFlow::globalVarRef("atob") or // ascii to binary
      callee = DataFlow::moduleImport("atob") or
      callee = DataFlow::moduleMember("abab", "atob") or
      callee = DataFlow::moduleMember("b2a", "atob") or
      callee = DataFlow::moduleMember("b64-lite", "atob") or
      callee = DataFlow::moduleMember("b64-lite", "fromBase64") or
      callee = DataFlow::moduleMember("b64u", "decode") or
      callee = DataFlow::moduleMember("b64u", "fromBase64") or
      callee = DataFlow::moduleMember("b64u-lite", "fromBase64Url") or
      callee = DataFlow::moduleMember("b64u-lite", "toBinaryString") or
      callee = DataFlow::moduleMember("base64url", "decode") or
      callee = DataFlow::moduleMember("base64url", "fromBase64") or
      callee = DataFlow::moduleMember("base64-url", "decode") or
      callee = DataFlow::moduleMember("base64-js", "toByteArray") or
      callee = DataFlow::moduleMember("urlsafe-base64", "decode"))
  }

  /**
   * Decoding by calling a base64 decoder.
   */
  class Base64Decoding extends DecodingKind {
    Base64Decoding() { this = "Base64Decoding" }
    
    override predicate isDecoderInput(DataFlow::Node node) {
      node = base64DecoderCall().getArgument(0)
    }
  }
}
