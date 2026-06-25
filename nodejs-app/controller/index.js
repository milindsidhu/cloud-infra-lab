var express = require("express");
var router = express.Router();
var os = require("os");

var VERSION = "1.7.2-beta";
var BG_COLOR = "green";

router.get("/", function(req, res) {
    var response = "<body  style=\"text-align: center; background-color:" + BG_COLOR + ";\"> " +
                    "<h1>Sample Node Application</h1>" +
                    "<h2>Application Version: " + VERSION + "</h2>" +
                    "<h3>Serving from host: " + os.hostname() + "</h3>"  +
                    "</body>";
    res.send(response);
});

module.exports = router;
