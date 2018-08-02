let _ = require('lodash');
let express = require('express');

let app = express();

app.get('/redir', function(req, res) {
  let nextUrl = req.query.nextUrl;
  if (!isValidUrl(nextUrl)) {
    res.status(500);
    return;
  }
  res.redirect(decodeURI(nextUrl)); // NOT OK
});

app.get('/echo', function(req, res) {
  let data = _.escape(req.query.data);
  let object = JSON.parse(data); // NOT OK
});
