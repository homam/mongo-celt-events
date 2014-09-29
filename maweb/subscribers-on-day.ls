{
	promises: {
		serial-map
		promise-monad
		new-promise
		from-error-only-callback
		from-error-value-callback
		to-callback
	}
} = require \async-ls
{map} = require \prelude-ls
moment = require \moment
sql = require \mssql
fs = require \fs

sql-config =
	user: 'Mobitrans_EF_User'
	password: 'g^h8yt#H'
	server: '172.30.0.165'
	database: 'Mobitrans'



start = moment \2014-09-05 


query-sql = (start) ->
	console.log "DOING ", start.format "YYYY-MM-DD"
	end = start.clone!.add \days, 1
	query = "SELECT U.UserId as userId, C.ISO_Code as country, (CASE WHEN A.UA LIKE '%Android 4%' THEN 'Android' ELSE 'iOS' END) AS os FROM dbo.Subscribers S WITH (NOLOCK) 
			INNER JOIN dbo.ML_User U WITH (NOLOCK) ON U.SubscriberId = S.SubscriberId 
			INNER JOIN dbo.Web_Subscriptions W WITH (NOLOCK) ON W.SubscriberId = S.SubscriberId AND W.Source = 1 
			INNER JOIN dbo.Wap_Visits V WITH (NOLOCK) ON V.VID = W.VisitId 
			INNER JOIN dbo.Wap_Visits_Ua A WITH (NOLOCK) ON A.UA_Id = V.UA_Id AND (A.UA LIKE '%Android 4%' OR A.UA LIKE '%iphone%' OR A.UA LIKE '%ipad%' OR A.UA LIKE '%ipod%') 
			INNER JOIN dbo.Operators O WITH (NOLOCK) ON O.Id = S.OC 
			INNER JOIN dbo.Countries C ON C.CountryId = O.Country 
			WHERE S.Service BETWEEN 3100 AND 3200 
			AND S.Sub_Created BETWEEN '#{start.format "YYYY-MM-DD"}' AND '#{end.format "YYYY-MM-DD"}'"

	connection = new sql.Connection sql-config

	(from-error-only-callback connection.connect, connection)!
		|> promise-monad.fbind -> 
			request = new sql.Request connection
			(from-error-value-callback request.query, request) query
		|> promise-monad.fbind (records) ->
			(res,rej) <- new-promise
			userIds = records #  records |> map (.userId)
			(err) <- fs.write-file "data/#{start.format "YYYY-MM-DD"}.json", (JSON.stringify userIds), encoding: \utf8
			res userIds
		|> promise-monad.fmap (records) -> 
			console.log "DONE ", start.format "YYYY-MM-DD"
			connection.close!
			records


# console.log <| [start.clone!.add \days, i for i in [0 to 22]] 
serial-map query-sql, [start.clone!.add \days, i for i in [0 to 22]]
	..then -> console.log "DONE!"
	..catch -> console.log \error, it