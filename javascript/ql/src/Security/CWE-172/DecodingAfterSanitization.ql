import javascript
import semmle.javascript.security.dataflow.DecodingAfterSanitization::DecodingAfterSanitization

from Configuration cfg, DataFlow::Node src, DataFlow::Node sink
where cfg.hasFlow(src, sink)
select sink, "Decoding invalidates prior sanitization performed $@.", src, "here"
