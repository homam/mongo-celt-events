{
	promises: {
		promise-monad
		new-promise
		from-error-only-callback
		from-error-value-callback
		to-callback
	}
} = require \async-ls
{map} = require \prelude-ls
sql = require \mssql
fs = require \fs

sql-config =
	user: 'Mobitrans_EF_User'
	password: 'g^h8yt#H'
	server: '172.30.0.165'
	database: 'Mobitrans'

sql-query = fs.read-file-sync 'sql-queries/sql-query.sql', 'utf8'

# > [Int] -> Promise [SQL-Record]
query-sql = (user-ids) ->
	query = sql-query.replace "{{VIDs}}", user-ids

	connection = new sql.Connection sql-config

	(from-error-only-callback connection.connect, connection)!
		|> promise-monad.fbind -> 
			request = new sql.Request connection
			(from-error-value-callback request.query, request) query
		|> promise-monad.fmap (records) -> 
			connection.close!
			records


fake-query-sql = (user-ids) ->
	is-subscribed = -> Math.random! > 0.9
	is-active = -> Math.random! > 0.5
	is-active12 = ->  Math.random! > 0.4
	devices = [{"wurfl_device_id":"samsung_gt_i9300_ver1_suban43","brand_name":"Samsung","model_name":"GT-I9300","marketing_name":"Galaxy S III"},{"wurfl_device_id":"samsung_gt_i9500_ver1_suban44","brand_name":"Samsung","model_name":"GT-I9500","marketing_name":"Galaxy S4"},{"wurfl_device_id":"samsung_gt_i8262_ver1","brand_name":"Samsung","model_name":"GT-I8262","marketing_name":"Galaxy Duos"},{"wurfl_device_id":"samsung_gt_i9105_ver1_suban41","brand_name":"Samsung","model_name":"GT-I9105","marketing_name":"Galaxy SII Plus"},{"wurfl_device_id":"samsung_gt_s7562_ver1_suban41","brand_name":"Samsung","model_name":"GT-S7562","marketing_name":"Galaxy S Duos"},{"wurfl_device_id":"samsung_sm_t210_ver1","brand_name":"Samsung","model_name":"SM-T210","marketing_name":"Galaxy Tab 3 7.0"},{"wurfl_device_id":"generic_android","brand_name":"Generic","model_name":"Android","marketing_name":""}]

	records = user-ids |> map (user-id) ->
		subscribed = is-subscribed!

		
		{
			visitId: user-id
			submissionId: if not subscribed then null else Math.floor(Math.random! * 10000000 + 10000000)
			subscriberId: if not subscribed then null else Math.floor(Math.random! * 1000000 + 1000000)
			active12: if not subscribed then false else is-active12!
			active: if not subscribed then false else is-active!
		} <<< devices[Math.floor(Math.random! * devices.length)]

	(res, rej) <- new-promise
	res records


exports <<< {
	query-sql
	fake-query-sql
}

# (err, res) <- to-callback <| fake-query-sql [1,2,3,4,5]
# console.log \error, err if !!err
# console.log res
# connection.close!
