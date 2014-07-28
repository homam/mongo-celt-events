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


# -- Queries -- 

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


[
	* \daily-chapters, \./queries/daily-chapters
	* \daily-cards, \./queries/daily-cards-flips-chapters-courses
	* \daily-time-spent, \./queries/daily-time-spent
	* \daily-opens, \./queries/daily-opens
	* \daily-ratings, \./queries/daily-ratings
	* \daily-depth, \./queries/daily-depth
	* \daily-eocs, \./queries/daily-eocs
	* \popular-courses, \./queries/popular-courses

] |> each ([req-path, module-path]) ->
	app.get do
		"/query/#req-path/:durationFrom/:durationTo/:countries?/:sampleFrom?/:sampleTo?"
		query-and-result (db, req, res) -> 
			params = req.params
			(require module-path) do
				db
				to-unix-time params.durationFrom
				to-unix-time params.durationTo
				to-country-array params.countries
				to-unix-time params.sampleFrom
				to-unix-time params.sampleTo


[
	* \histogram-flips-cumulative, \./queries/histogram-flips-cumulative
	* \histogram-timespent-cumulative, \./queries/histogram-timespent-cumulative
	* \histogram-timespent-onday, \./queries/histogram-timespent-onday
	* \histogram-flips-onday, \./queries/histogram-flips-onday
	* \histogram-eocs-cumulative, \./queries/histogram-eocs-cumulative
	* \histogram-eocs-onday, \./queries/histogram-eocs-onday
	* \daily-conversions, \./queries/daily-conversions
	* \funnel-depth-cumulative, \./queries/funnel-depth-cumulative
	* \funnel-depth-onday, \./queries/funnel-depth-onday

] |> each ([req-path, module-path]) ->
	app.get do
		"/query/#req-path/:durationFrom/:durationTo/:countries?/:sampleFrom?/:sampleTo?/:howManyDays?"
		query-and-result (db, req, res) -> 
			params = req.params
			(require module-path) do
				db
				to-unix-time params.durationFrom
				to-unix-time params.durationTo
				to-country-array params.countries
				to-unix-time params.sampleFrom
				to-unix-time params.sampleTo
				to-int params.howManyDays




# -- Views --

app.post do
	"/login"
	(req, res) ->

		if "tomato" == req.body.password

			res.cookie 'loggedin', '1', { maxAge: 48*60*60*1000, httpOnly: true }
			res.redirect (req.get \Referrer .split \backto= .1) or \/

		res.render 'login-view/index.html', {message: "Invalid Password"}
		res.end!

[
	* \/, \index
	* \/usage, \usage
	* \/popular, \popular
	* \/login, \login
	* \/usageh, \usageh
	* \/timeh, \timeh
	* \/chaptersh, \chaptersh
	* \/conversions, \conversions
	* \/funnel, \funnel
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
console.log "server started on port #{app.get \port} " 
