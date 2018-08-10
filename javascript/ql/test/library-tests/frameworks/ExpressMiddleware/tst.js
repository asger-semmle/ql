let express = require('express');

let app = express();

function setupThroughArgument(app) {
  app.get('/', makeMiddleware(1));
}

function setupThroughCapture() {
  app.get('/', makeMiddleware(2));
}

function returnRouter() {
  let router = express.Router();
  router.get('/', makeMiddleware(3));
  return router;
}

app.get('/', makeMiddleware(0));

setupThroughArgument(app);
setupThroughCapture();
app.get('/', returnRouter());

app.get('/', makeMiddleware(4));
