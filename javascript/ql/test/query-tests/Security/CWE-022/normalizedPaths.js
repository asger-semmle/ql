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
  
  // BAD: normalized path can be absolute
  if (!normalizedPath.startsWith(".."))
    res.write(fs.readFileSync(normalizedPath));
  
  // GOOD: path is relative and cannot contain path traversal
  if (!normalizedPath.startsWith("..") && !normalizedPath.startsWith("/"))
    res.write(fs.readFileSync(normalizedPath));
  
  if (!normalizedPath.startsWith("..")) {
    // GOOD: path cannot be interpreted as relative
    res.write(fs.readFileSync("./" + normalizedPath));

    // BAD: path can be absolute
    res.write(fs.readFileSync(normalizedPath + "/index.html"));
  }

  // GOOD: path cannot be interpreted as relative
  let normalizedRelativePath = pathModule.normalizePath("./" + path);
  if (!normalizedRelativePath.startsWith(".."))
    res.write(fs.readFileSync(normalizedRelativePath));
  
  // BAD: path can still use ../
  res.write(fs.readFileSync("./" + path));
  
  // BAD: absolute path
  if (pathModule.isAbsolute(path))
    res.write(fs.readFileSync(path));

  // BAD: absolute path can contain ../
  if (pathModule.isAbsolute(path) && path.startsWith("/home/user/www"))
    res.write(fs.readFileSync(path));
  
  // BAD: absolute path (normalized or not)
  if (pathModule.isAbsolute(normalizedPath))
    res.write(fs.readFileSync(normalizedPath));

  // GOOD: normalized absolute path with folder check
  if (pathModule.isAbsolute(normalizedPath) && normalizedPath.startsWith("/home/user/www"))
    res.write(fs.readFileSync(normalizedPath));

  // GOOD: combined absoluteness and folder check in one startsWith call
  if (normalizedPath.startsWith("/home/user/www"))
    res.write(fs.readFileSync(normalizedPath));

  // GOOD: normalized relative path that does not start with ../
  if (normalizedPath[0] !== "/" && normalizedPath[0] !== ".")
    res.write(fs.readFileSync(normalizedPath));

  // GOOD: realpath is normalized and absolute
  let realpath = fs.realpathSync(path);
  if (realpath.startsWith("/home/user/www"))
    res.write(fs.readFileSync(realpath));

  // BAD: suffix has no effect
  res.write(fs.readFileSync(pathModule.join(path, 'index.html')));
  res.write(fs.readFileSync(pathModule.join(normalizedPath, 'index.html')));
  res.write(fs.readFileSync(pathModule.join(realpath, 'index.html')));
  
  // BAD: joining with relative path is not enough
  res.write(fs.readFileSync(pathModule.join('.', path)));
  res.write(fs.readFileSync(pathModule.join('.', normalizedPath)));

  // BAD: joining with absolute path is not enough
  res.write(fs.readFileSync(pathModule.join('/home/user/www', path)));
  res.write(fs.readFileSync(pathModule.join('/home/user/www', normalizedPath)));

  // GOOD: absolute normalized paths are safe
  res.write(fs.readFileSync(pathModule.join('.', realpath)));
  res.write(fs.readFileSync(pathModule.join('/home/user/www', realpath)));

  // GOOD: coercion to relative followed by '..' check.
  let joinedRelative = pathModule.join('.', path);
  if (!joinedRelative.startsWith('..')) {
    res.write(fs.readFileSync(joinedRelative));
    res.write(fs.readFileSync("/home/user/www/" + joinedRelative));
  }

  // GOOD: coercion to absolute followed by homedir check
  let joinedAbsolute = pathModule.join('/home/user/www', path);
  if (joinedAbsolute.startsWith('/home/user/www')) {
    res.write(fs.readFileSync(joinedAbsolute));
  }
  // BAD: wrong polarity
  if (!joinedAbsolute.startsWith('/home/user/www')) {
    res.write(fs.readFileSync(joinedAbsolute));
  }
});
