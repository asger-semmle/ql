function escapeHtml(s) {
    var amp = /&/g, lt = /</g, gt = />/g;
    return s.toString()
        .replace(amp, '&amp;')
        .replace(lt, '&lt;')
        .replace(gt, '&gt;');
}

function escapeAttr(s) {
    return s.toString()
         .replace(/</g, '%3C')
         .replace(/'/g, '%22')
         .replace(/"/g, '%27');
}

function test() {
  var tainted = window.location.search.substring(1);
  var elt = document.createElement();
  elt.innerHTML = "<a href=\"" + escapeAttr(tainted) + "\">" + escapeHtml(tainted) + "</a>"; // OK
  elt.innerHTML = "<div>" + escapeAttr(tainted) + "</div>"; // NOT OK, but not flagged
}

function whitelistReplace() {
  let taint = window.location.search.substring(1);
  var elt = document.createElement();

  elt.innerHTML = taint.replace(/[^\w\d]/g, ''); // OK
  elt.innerHTML = taint.replace(/[^a-z0-9]/g, ''); // OK

  elt.innerHTML = taint.replace(/[^0-z]/g, ''); // NOT OK
  elt.innerHTML = taint.replace(/^[^\w\d]/g, ''); // NOT OK
  elt.innerHTML = taint.replace(/[^\w\d]$/g, ''); // NOT OK
  elt.innerHTML = taint.replace(/<script/gi, ''); // NOT OK
  elt.innerHTML = taint.replace(/[^\w\d<>'"&]/g, ''); // NOT OK
}

function captureGroups() {
  let taint = window.location.search.substring(1);
  var elt = document.createElement();

  elt.innerHTML = /example.com\?data=(.*)/.exec(taint)[1]; // NOT OK
  elt.innerHTML = /example.com\?data=([a-z]*)/.exec(taint)[1]; // OK
}
