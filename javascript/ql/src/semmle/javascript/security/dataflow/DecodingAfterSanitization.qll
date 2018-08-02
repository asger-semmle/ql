import javascript

module DecodingAfterSanitization {
  abstract class SanitizationKind extends string {
    bindingset[this]
    SanitizationKind() { any() }

    abstract predicate isSanitizer(DataFlow::Node sanitizer, DataFlow::Node output);
    abstract predicate isUnsafeDecoding(DecodingKind kind);
  }

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

  class RegexpReplaceSanitization extends SanitizationKind {
    RegexpReplaceSanitization() { this = "RegexpReplaceSanitization" }
    
    override predicate isSanitizer(DataFlow::Node sanitizer, DataFlow::Node output) {
      sanitizer = output and
      sanitizer.(DataFlow::MethodCallNode).getMethodName() = "replace"
    }

    override predicate isUnsafeDecoding(DecodingKind kind) {
      any()
    }
  }

  private predicate isValidationCandidate(DataFlow::CallNode call) {
    exists(string name | name = call.getCalleeName() |
      name.regexpMatch("(?i)(is|has|contains|endswith|startswith)(in|un)?(safe|valid|expected|whitelist|blacklist|correct|secure|loggedin|.*admin|owne[rd]|format|relative|absolute|path).*")
      or
      name.regexpMatch("(?i)(check|validat|verif).*"))
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

  class GuardSanitization extends SanitizationKind {
    GuardSanitization() { this = "GuardSanitization" }
    
    override predicate isSanitizer(DataFlow::Node sanitizer, DataFlow::Node output) {
      sanitizer.(TaintTracking::SanitizerGuardNode).blocks(output)
    }

    override predicate isUnsafeDecoding(DecodingKind kind) {
      any()
    }
  }

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

  class Base64Decoding extends DecodingKind {
    Base64Decoding() { this = "Base64Decoding" }
    
    override predicate isDecoderInput(DataFlow::Node node) {
      node = base64DecoderCall().getArgument(0)
    }
  }
}
