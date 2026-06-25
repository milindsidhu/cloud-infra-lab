var PORT = process.env.PORT || 8080;

var http = require("http");
var express = require("express");
var path = require("path");
var controller = require("./controller");

var app = express();
app.server = http.createServer(app);

app.use("/", controller);

app.server.listen(PORT, function() {
    console.log("app started on port " + PORT);
});

module.exports.app;
