var fs = require('fs'),
    http = require('http'),
    url = require('url'),
    sanitize = require('sanitize-filename'),
    pathModule = require('path')
    ;


var server = http.createServer(function(req, res) {
  let path = url.parse(req.url, true).query.path;
  
  // GOOD: path is sanitized
  let normalizedPath = pathModule.normalize(path);
  if (!normalizedPath.startsWith("."))
    res.write(fs.readFileSync(normalizedPath));

  // GOOD: path is sanitized
  if (!normalizedPath.startsWith(".."))
    res.write(fs.readFileSync(normalizedPath));

  // GOOD: path is only sanitized on Unix - not perfect but good enough for now
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
});
