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
{map, pairs-to-obj, filter, each} = require \prelude-ls
moment = require \moment

config = require \./config
connect-db = config.connect

# start the http server: lsc server.ls --port=3002
{port} = (process.argv.slice(2) |> require \minimist)
port = port or config.port


app = express!
app.use body-parser.urlencoded extended: true
app.set \port, port
app.set \views, __dirname + \/
app.engine \.html, (require \ejs).__express
app.use <| (require \cookie-parser)!
app.set 'view engine', \ejs
app.use \/libs, express.static \../public/libs
app.use \/graphs, express.static \../public/graphs
app.use \/data, express.static \../public/data



write-error = (res, error) ->
	console.log \error, error
	res.status-code = 500
	res.write "Error!\n" + error

# aggregate = require \./../queries/banners-summary
# aggregate-response = (aggregation, req, res) -->
# 	(error, results) <- to-callback aggregation
# 	return write-error res, error if !!error
# 	res.set-header \content-type, \application/json
# 	res.write <| JSON.stringify results, null, 4
# 	res.end!

# app.get "/query/banners", aggregate-response (aggregate db, {
# 		_id: "$creativeId"
# 		banner: $first: "$banner"
# })

# app.get "/q/:keyvalues/:grouping", (req, res) -> 
# 	filtering-obj = if '_' == req.params.keyvalues then {} else req.params.keyvalues.split \, |> (map -> it.split \:) |> pairs-to-obj
# 	aggregate-response (aggregate db, {
# 		_id: "$#{req.params.grouping}"
# 	}, filtering-obj), req, res

# app.get "/query/banners/:creativeId/:grouping", (req, res) -> aggregate-response (aggregate db, {
# 	_id: "$#{req.params.grouping}"
# },{creativeId: req.params.creativeId}), req, res

# app.get "/query/banners/:creativeId/:filteringkey/:filteringvalue/:grouping", (req, res) -> aggregate-response (aggregate db, {
# 	_id: "$#{req.params.grouping}"
# },{creativeId: req.params.creativeId, "#{req.params.filteringkey}": "#{req.params.filteringvalue}"}), req, res

check-empty = (s) -->
	return ('undefined' == (typeof s) or !s or s == '-')


to-unix-time = (s) ->
	return null if check-empty s
	moment s .unix! * 1000

to-int = (s) ->
	return null if check-empty s
	i = parseInt s
	if i < Infinity then i else null


to-array = (s) ->
	return null if check-empty s
	s.split \, |> filter (-> !!it)

to-country-array = (s) ->
	arr = to-array s
	return null if !arr
	arr |> filter (-> 2 == it.length) |> map (-> it.toUpperCase!)



query-and-result = (promise, req, res) -->
	db = connect-db!
	(error, results) <- to-callback <| promise db, req, res
		|> promise-monad.fmap (results) ->
			res.set-header \content-type, \application/json
			res.write <| JSON.stringify results, null, 4

	write-error res, error if !!error
	
	res.end!
	db.close!

app.get do
	"/query/latest-users"
	query-and-result (db, req, res) -> (require \./queries/latest-users) db, parseInt req.query[\limit]


app.get do
	"/query/daily-chapters/:durationFrom/:durationTo/:countries?/:sampleFrom?/:sampleTo?"
	query-and-result (db, req, res) -> 
		params = req.params
		(require \./queries/daily-chapters) do
			db
			to-unix-time params.durationFrom
			to-unix-time params.durationTo
			to-country-array params.countries
			to-unix-time params.sampleFrom
			to-unix-time params.sampleTo


app.get do
	"/query/daily-cards/:durationFrom/:durationTo/:countries?/:sampleFrom?/:sampleTo?"
	query-and-result (db, req, res) -> 
		params = req.params
		(require \./queries/daily-cards-flips-chapters-courses) do
			db
			to-unix-time params.durationFrom
			to-unix-time params.durationTo
			to-country-array params.countries
			to-unix-time params.sampleFrom
			to-unix-time params.sampleTo


app.get do
	"/query/daily-time-spent/:durationFrom/:durationTo/:countries?/:sampleFrom?/:sampleTo?"
	query-and-result (db, req, res) -> 
		params = req.params
		(require \./queries/daily-time-spent) do
			db
			to-unix-time params.durationFrom
			to-unix-time params.durationTo
			to-country-array params.countries
			to-unix-time params.sampleFrom
			to-unix-time params.sampleTo




app.get do
	"/query/daily-opens/:durationFrom/:durationTo/:countries?/:sampleFrom?/:sampleTo?"
	query-and-result (db, req, res) -> 
		params = req.params
		(require \./queries/daily-opens) do
			db
			to-unix-time params.durationFrom
			to-unix-time params.durationTo
			to-country-array params.countries
			to-unix-time params.sampleFrom
			to-unix-time params.sampleTo


app.get do
	"/query/daily-depth/:durationFrom/:durationTo/:countries?/:sampleFrom?/:sampleTo?"
	query-and-result (db, req, res) -> 
		params = req.params
		(require \./queries/daily-depth) do
			db
			to-unix-time params.durationFrom
			to-unix-time params.durationTo
			to-country-array params.countries
			to-unix-time params.sampleFrom
			to-unix-time params.sampleTo


app.get do
	"/query/popular-courses/:durationFrom/:durationTo/:countries?/:sampleFrom?/:sampleTo?"
	query-and-result (db, req, res) -> 
		params = req.params
		(require \./queries/popular-courses) do
			db
			to-unix-time params.durationFrom
			to-unix-time params.durationTo
			to-country-array params.countries
			to-unix-time params.sampleFrom
			to-unix-time params.sampleTo

app.get do
	"/query/daily-conversions/:durationFrom/:durationTo/:countries?/:sampleFrom?/:sampleTo?"
	query-and-result (db, req, res) -> 
		params = req.params
		(require \./queries/daily-conversions) do
			db
			to-unix-time params.durationFrom
			to-unix-time params.durationTo
			to-country-array params.countries
			to-unix-time params.sampleFrom
			to-unix-time params.sampleTo


app.post do
	"/login"
	(req, res) ->

		if "tomato" == req.body.password

			res.cookie 'loggedin', '1', { maxAge: 48*60*60*1000, httpOnly: true }
			res.redirect (req.get \Referrer .split \backto= .1) or \/

		res.render 'login-view/index.html', {message: "Invalid Password"}
		res.end!

[
	[\/, \index]
	[\/usage, \usage]
	[\/popular, \popular]
	[\/login, \login]
] |> each ([path, dir]) ->

	app.use "/#dir/scripts/", express.static "#{dir}-view/scripts"
	app.use "/#dir/styles/", express.static "#{dir}-view/styles"
	app.get path, (req, res) ->
		if "/login" != req.path and "1" != req.cookies?.loggedin
			res.redirect "/login?backto=#{req.url}"
		else
			res.render "#{dir}-view/index.html", {title: 'Hello!'}
			res.end!








app.listen app.get \port
console.log "server started on port #{app.get \port}"
