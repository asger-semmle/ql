var fs = require('fs'),
    http = require('http'),
    url = require('url'),
    sanitize = require('sanitize-filename'),
    pathModule = require('path')
    ;


var server = http.createServer(function(req, res) {
  let path = url.parse(req.url, true).query.path;
  
  let normalizedPath = pathModule.normalize(path);
  if (!pathModule.isAbsolute(normalizedPath)) {
    // GOOD: path is sanitized
    if (!normalizedPath.startsWith("."))
      res.write(fs.readFileSync(normalizedPath));
  
    // GOOD: path is sanitized
    if (!normalizedPath.startsWith(".."))
      res.write(fs.readFileSync(normalizedPath));
  
    // GOOD: path is sanitized
    if (!normalizedPath.startsWith("../"))
      res.write(fs.readFileSync(normalizedPath));
  
    // BAD: wrong polarity
    if (normalizedPath.startsWith("."))
      res.write(fs.readFileSync(normalizedPath));
  
    // BAD: normalized path can still contain path traversal
    res.write(fs.readFileSync(normalizedPath));
    
    // BAD: without normalization, startsWith can be bypassed by x/../../
    if (path.startsWith(".."))
      res.write(fs.readFileSync(path));
  }
});
