var fs = require('fs'),
    express = require('express'),
    url = require('url'),
    sanitize = require('sanitize-filename'),
    pathModule = require('path')
    ;

let app = express();

app.get('/basic', (req, res) => {
  let path = req.query.path;

  res.sendFile(path); // NOT OK
  res.sendFile('./' + path); // NOT OK
  res.sendFile(path + '/index.html'); // NOT OK
  res.sendFile(pathModule.join(path, 'index.html')); // NOT OK
  res.sendFile(pathModule.join('/home/user/www', path)); // NOT OK
});

app.get('/normalize', (req, res) => {
  let path = pathModule.normalize(req.query.path);

  res.sendFile(path); // NOT OK
  res.sendFile('./' + path); // NOT OK
  res.sendFile(path + '/index.html'); // NOT OK
  res.sendFile(pathModule.join(path, 'index.html')); // NOT OK
  res.sendFile(pathModule.join('/home/user/www', path)); // NOT OK
});

app.get('/normalize-notAbsolute', (req, res) => {
  let path = pathModule.normalize(req.query.path);

  if (pathModule.isAbsolute(path))
    return;
   
  res.sendFile(path); // NOT OK

  if (!path.startsWith("."))
    res.sendFile(path); // OK
  else
    res.sendFile(path); // NOT OK - wrong polarity
  
  if (!path.startsWith(".."))
    res.sendFile(path); // OK
  
  if (!path.startsWith("../"))
    res.sendFile(path); // OK

  if (!path.startsWith(".." + pathModule.sep))
    res.sendFile(path); // OK
});

app.get('/normalize-noInitialDotDot', (req, res) => {
  let path = pathModule.normalize(req.query.path);
  
  if (path.startsWith(".."))
    return;

  res.sendFile(path); // NOT OK - could be absolute

  res.sendFile("./" + path); // OK - coerced to relative

  res.sendFile(path + "/index.html"); // NOT OK - not coerced

  if (!pathModule.isAbsolute(path))
    res.sendFile(path); // OK
  else
    res.sendFile(path); // NOT OK
});

app.get('/prepend-normalize', (req, res) => {
  // Coerce to relative prior to normalization
  let path = pathModule.normalize('./' + req.query.path);

  if (!path.startsWith(".."))
    res.sendFile(path); // OK
  else
     res.sendFile(path); // NOT OK
});

app.get('/absolute', (req, res) => {
  let path = req.query.path;
  
  if (!pathModule.isAbsolute(path))
    return;

  res.write(fs.readFileSync(path)); // NOT OK

  if (path.startsWith('/home/user/www'))
    res.write(fs.readFileSync(path)); // NOT OK - can still contain '../'
});

app.get('/normalized-absolute', (req, res) => {
  let path = pathModule.normalize(req.query.path);
  
  if (!pathModule.isAbsolute(path))
    return;
  
  res.write(fs.readFileSync(path)); // NOT OK

  if (path.startsWith('/home/user/www'))
    res.write(fs.readFileSync(path)); // OK
});

app.get('/combined-check', (req, res) => {
  let path = pathModule.normalize(req.query.path);
  
  // Combined absoluteness and folder check in one startsWith call
  if (path.startsWith("/home/user/www"))
    res.sendFile(path); // OK

  if (path[0] !== "/" && path[0] !== ".")
    res.sendFile(path); // OK
});

app.get('/realpath', (req, res) => {
  let path = fs.realpathSync(req.query.path);

  res.sendFile(path); // NOT OK
  res.sendFile(pathModule.join(path, 'index.html')); // NOT OK

  if (path.startsWith("/home/user/www"))
    res.sendFile(path); // OK - both absolute and normalized before check
    
  res.sendFile(pathModule.join('.', path)); // OK - normalized and coerced to relative
  res.sendFile(pathModule.join('/home/user/www', path)); // OK
});

app.get('/coerce-relative', (req, res) => {
  let path = pathModule.join('.', req.query.path);

  if (!path.startsWith('..'))
    res.sendFile(path); // OK
  else
    res.sendFile(path); // NOT OK
});

app.get('/coerce-absolute', (req, res) => {
  let path = pathModule.join('/home/user/www', req.query.path);

  if (path.startsWith('/home/user/www'))
    res.sendFile(path); // OK
  else
    res.sendFile(path); // NOT OK
});

app.get('/concat-after-normalization', (req, res) => {
  let path = 'foo/' + pathModule.normalize(req.query.path);

  if (!path.startsWith('..'))
    res.sendFile(path); // NOT OK - prefixing foo/ invalidates check
  else
    res.sendFile(path); // NOT OK

  if (!path.includes('..'))
    res.sendFile(path); // OK
});

app.get('/noDotDot', (req, res) => {
  let path = pathModule.normalize(req.query.path);

  if (path.includes('..'))
    return;

  res.sendFile(path); // NOT OK - can still be absolute

  if (!pathModule.isAbsolute(path))
    res.sendFile(path); // OK
  else
    res.sendFile(path); // NOT OK
});

app.get('/join-regression', (req, res) => {
  let path = req.query.path;

  // Regression test for a specific corner case:
  // Some guard nodes sanitize both branches, but for a different set of flow labels.
  // Verify that this does not break anything.
  if (pathModule.isAbsolute(path)) {path;} else {path;}
  if (path.startsWith('/')) {path;} else {path;}
  if (path.startsWith('/x')) {path;} else {path;}
  if (path.startsWith('.')) {path;} else {path;}

  res.sendFile(path); // NOT OK

  if (pathModule.isAbsolute(path))
    res.sendFile(path); // NOT OK
  else
    res.sendFile(path); // NOT OK

  if (path.includes('..'))
    res.sendFile(path); // NOT OK
  else
    res.sendFile(path); // NOT OK

  if (!path.includes('..') && !pathModule.isAbsolute(path))
    res.sendFile(path); // OK
  else
    res.sendFile(path); // NOT OK

  let normalizedPath = pathModule.normalize(path);
  if (normalizedPath.startsWith('/home/user/www'))
    res.sendFile(normalizedPath); // OK
  else
    res.sendFile(normalizedPath); // NOT OK

  if (normalizedPath.startsWith('/home/user/www') || normalizedPath.startsWith('/home/user/public'))
    res.sendFile(normalizedPath); // OK
  else
    res.sendFile(normalizedPath); // NOT OK
});
