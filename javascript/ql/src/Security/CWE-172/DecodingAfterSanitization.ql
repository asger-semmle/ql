import javascript
import semmle.javascript.security.dataflow.DecodingAfterSanitization::DecodingAfterSanitization

from Configuration cfg, SanitizationKind sanitizerKind, DataFlow::Node sanitizer, DataFlow::Node src, DataFlow::Node sink
where cfg.hasFlow(src, sink)
  and sanitizerKind.isSanitizer(sanitizer, src)
select sink, "Decoding invalidates prior sanitization performed $@.", sanitizer, "here"
