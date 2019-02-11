goog.module('test');

goog.require('goog.bind');
goog.require('goog.partial');

function callback(x, y, z, w) {
  sink(x); // NOT OK
  sink(y); // OK
  sink(z); // NOT OK
  sink(w); // OK
}

goog.bind(callback, {}, source(), "safe", source())("safe");

function callback2(x, y, z, w) {
  sink(x); // NOT OK
  sink(y); // OK
  sink(z); // NOT OK
  sink(w); // OK
}

goog.partial(callback2, source(), "safe", source())("safe");
