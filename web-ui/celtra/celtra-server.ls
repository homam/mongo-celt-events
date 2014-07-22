{
	promises: {
		promise-monad
		new-promise
		to-callback
	}
} = require \async-ls
express = require \express
path = require \path
http = require \http
body-parser = require \body-parser
{map, pairs-to-obj} = require \prelude-ls

#db = require("mongojs").connect \localhost/Celtra-events, [\reducedEvents]
db = require("mongojs").connect \172.30.0.160:27017/Celtra-events, [\reducedEvents]

# start the http server: lsc server.ls --port=3002
{port} = (process.argv.slice(2) |> require \minimist)
port = port or 3002


app = express!
app.use body-parser.urlencoded extended: true
app.set \port, port
app.set \views, __dirname + \/
app.engine \.html, (require \ejs).__express
app.set 'view engine', \ejs
app.use \/libs, express.static \../public/libs
app.use \/graphs, express.static \../public/graphs




write-error = (res, error) ->
	console.log \error, error
	res.status-code = 500
	res.write "Error!\n" + error
	res.end!

aggregate = require \./../queries/banners-summary
aggregate-response = (aggregation, req, res) -->
	(error, results) <- to-callback aggregation
	return write-error res, error if !!error
	res.set-header \content-type, \application/json
	res.write <| JSON.stringify results, null, 4
	res.end!

app.get "/query/banners", aggregate-response (aggregate db, {
		_id: "$creativeId"
		banner: $first: "$banner"
})

app.get "/q/:keyvalues/:grouping", (req, res) -> 
	filtering-obj = if '_' == req.params.keyvalues then {} else req.params.keyvalues.split \, |> (map -> it.split \:) |> pairs-to-obj
	aggregate-response (aggregate db, {
		_id: "$#{req.params.grouping}"
	}, filtering-obj), req, res

app.get "/query/banners/:creativeId/:grouping", (req, res) -> aggregate-response (aggregate db, {
	_id: "$#{req.params.grouping}"
},{creativeId: req.params.creativeId}), req, res

app.get "/query/banners/:creativeId/:filteringkey/:filteringvalue/:grouping", (req, res) -> aggregate-response (aggregate db, {
	_id: "$#{req.params.grouping}"
},{creativeId: req.params.creativeId, "#{req.params.filteringkey}": "#{req.params.filteringvalue}"}), req, res


app.use \/index/scripts/, express.static \index-view/scripts
app.get /^\/(.*)/, (req, res) ->
	res.render \index-view/index.html, {title: 'Hello!'}
	res.end!

app.listen app.get \port
console.log "server started on port #{app.get \port}"
