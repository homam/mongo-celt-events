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
	..use body-parser.urlencoded extended: true
	..set \port, port
	..set \views, __dirname + \/
	..engine \.html, (require \ejs).__express
	..use <| (require \cookie-parser)!
	..set 'view engine', \ejs
	..use \/libs, express.static \../public/libs
	..use \/graphs, express.static \../public/graphs
	..use \/data, express.static \../public/data

write-error = (res, error) ->
	console.log \error, error
	res.status-code = 500
	res.write "Error!\n" + error


# -- Queries -- 

check-empty = (s) -->
	return ('undefined' == (typeof s) or !s or s == '-')


to-unix-time = (s) ->
	return null if check-empty s
	(moment s .unix! - new Date!.getTimezoneOffset! * 60) * 1000	


to-dubai-unix-time = (s) ->
	u = to-unix-time s
	return null if not u
	u -  (4 * 60 * 60 * 1000)


to-int = (s) ->
	return null if check-empty s
	i = parseInt s
	if i < Infinity then i else null

to-bool = (s) ->
	return null if check-empty s
	return \true == s.to-lower-case!


to-array = (s) ->
	return null if check-empty s
	s.split \, |> filter (-> !!it)

to-country-array = (s) ->
	arr = to-array s
	return null if !arr
	arr |> filter (-> 2 == it.length) |> map (-> it.toUpperCase!)

to-user-filter = (s)->
	return s

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
	"/query/qualified-leads/:countries/:flips/:hours/:sampleFrom/:sampleTo/:sources"
	query-and-result (db, req, res) -> 
		params = req.params
		(require \./queries/qualified-leads) do
			db
			to-country-array params.countries
			parseInt params.flips
			parseInt params.hours
			to-dubai-unix-time params.sampleFrom
			to-dubai-unix-time params.sampleTo
			to-array params.sources			

app.get do 
	"/query/qualified-leads2/:countries/:flips/:hours/:sampleFrom/:sampleTo/:sources"
	query-and-result (db, req, res) -> 
		params = req.params
		(require \./queries/qualified-leads2) do
			db
			to-country-array params.countries
			parseInt params.flips
			parseInt params.hours
			to-unix-time params.sampleFrom
			to-unix-time params.sampleTo
			to-array params.sources	
			params.purchased

[
	* \daily-chapters, \./queries/daily-chapters
	* \daily-cards, \./queries/daily-cards-flips-chapters-courses
	* \daily-time-spent, \./queries/daily-time-spent
	* \daily-opens, \./queries/daily-opens
	* \daily-ratings, \./queries/daily-ratings
	* \daily-subscriptions, \./queries/daily-subscriptions
	* \daily-depth, \./queries/daily-depth
	* \daily-eocs, \./queries/daily-eocs
	* \popular-courses, \./queries/popular-courses
	* \daily-push, \./queries/daily-push 
	* \daily-active-users, \./queries/daily-active-users
	* \purchased-for, \./queries/purchased-for
	* \heat-map, \./queries/heat-map
	* \purchased-day, \./queries/purchased-day
] |> each ([req-path, module-path]) ->
	app.get do
		"/query/#req-path/:durationFrom/:durationTo/:countries?/:sampleFrom?/:sampleTo?/:sources?"
		query-and-result (db, req, res) -> 
			params = req.params
			(require module-path) do
				db				
				to-dubai-unix-time params.durationFrom
				to-dubai-unix-time params.durationTo
				to-country-array params.countries
				to-dubai-unix-time params.sampleFrom
				to-dubai-unix-time params.sampleTo
				to-array params.sources

app.get do
	"/query/media-sources/:countries?"
	query-and-result (db, req, res) -> 
		(require \./queries/media-sources) do
			db
			to-country-array req.params.countries

[
	* \histogram-flips-cumulative, \./queries/histogram-flips-cumulative
	* \histogram-timespent-cumulative, \./queries/histogram-timespent-cumulative
	* \histogram-timespent-onday, \./queries/histogram-timespent-onday
	* \histogram-flips-onday, \./queries/histogram-flips-onday
	* \daily-conversions, \./queries/daily-conversions
	* \funnel-depth-cumulative, \./queries/funnel-depth-cumulative
	* \funnel-depth-onday, \./queries/funnel-depth-onday

] |> each ([req-path, module-path]) ->
	app.get do
		"/query/#req-path/:durationFrom/:durationTo/:countries?/:sampleFrom?/:sampleTo?/:howManyDays?/:userPaymentStatus?"

		query-and-result (db, req, res) -> 
			params = req.params

			(require module-path) do
				db
				to-dubai-unix-time params.durationFrom
				to-dubai-unix-time params.durationTo
				to-country-array params.countries
				to-dubai-unix-time params.sampleFrom
				to-dubai-unix-time params.sampleTo
				to-int params.howManyDays
				to-user-filter params.userPaymentStatus


[
	* \histogram-eocs-cumulative, \./queries/histogram-eocs-cumulative
	* \histogram-eocs-onday, \./queries/histogram-eocs-onday

] |> each ([req-path, module-path]) ->
	app.get do
		"/query/#req-path/:durationFrom/:durationTo/:countries?/:sampleFrom?/:sampleTo?/:howManyDays?/:uniqueCount?"
		query-and-result (db, req, res) -> 
			params = req.params
			(require module-path) do
				db
				to-dubai-unix-time params.durationFrom
				to-dubai-unix-time params.durationTo
				to-country-array params.countries
				to-dubai-unix-time params.sampleFrom
				to-dubai-unix-time params.sampleTo
				to-int params.howManyDays
				to-bool params.uniqueCount

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
	* \/subscriptions, \subscriptions
	* \/push, \push
	* \/flips, \flips
	* \/qualified-leads2, \qualified-leads2
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
