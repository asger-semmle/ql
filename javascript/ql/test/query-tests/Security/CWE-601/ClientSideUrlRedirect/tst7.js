// NOT OK
new Worker(document.location.search.substr(1));

// NOT OK
$("<script>").attr("src", document.location.search.substr(1));
