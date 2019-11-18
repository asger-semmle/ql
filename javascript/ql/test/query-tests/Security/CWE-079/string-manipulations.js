document.write(document.location.href.charCodeAt(0)); // OK

document.write(document.location); // NOT OK
document.write(document.location.href); // NOT OK
document.write(document.location.href.valueOf()); // NOT OK
document.write(document.location.search.substr(1).sup()); // NOT OK
document.write(document.location.href.toUpperCase()); // NOT OK
document.write(document.location.href.trimLeft()); // NOT OK
document.write(String.fromCharCode(document.location.search.substr(1))); // NOT OK
document.write(String(document.location.href)); // NOT OK
document.write(escape(document.location.href)); // OK (for now)
document.write(escape(escape(escape(document.location.href)))); // OK (for now)
