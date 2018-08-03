/**
 * @name Decoding after sanitization
 * @description Decoding data after sanitization may enable an attacker to bypass the sanitizer.
 * @kind problem
 * @problem.severity warning
 * @precision high
 * @id js/decoding-after-sanitization
 * @tags security
 *       external/cwe/cwe-172
 */

import javascript
import semmle.javascript.security.dataflow.DecodingAfterSanitization::DecodingAfterSanitization

from Configuration cfg, SanitizationKind sanitizerKind, DataFlow::Node sanitizer, DataFlow::Node src, DataFlow::Node sink
where cfg.hasFlow(src, sink)
  and sanitizerKind.isSanitizer(sanitizer, src)
select sink, "Decoding invalidates prior sanitization performed $@.", sanitizer, "here"
