function test() {
  var tainted = document.location.search

  $(tainted);                        // OK
  $("body", tainted);                // OK
  $("." + tainted);                  // OK
  $("<div id=\"" + tainted + "\">"); // NOT OK
  $("body").html("XSS: " + tainted); // NOT OK
  $(window.location.hash);           // OK
  $('<b>' + window.location.hash + '</b>'); // NOT OK
  $(window.location.hash.substr(1)); // NOT OK
  $(tainted.replace('?', ''));       // NOT OK
  $(("<b>" + "hello") + "blah" + tainted + "</b>"); // NOT OK
  $(`
  <div>
    ${tainted}
  </div>
  `); // NOT OK
}
