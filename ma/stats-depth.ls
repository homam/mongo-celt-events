{map, sort, sort-by, mean, filter, first, group-by, concat-map, foldl, Obj} = require \prelude-ls
db = require \./config .connect!

depths = {"Home":1, "Chapter":2, "Flashcard":3, "EOC":4, "Question":5, "EOQ":6}


one-hour = 1000*60*60
one-day =  one-hour*24

now = new Date! .get-time!

first-day = 16259
today = now / one-day - ((now / one-day)%1)

from-time = first-day * one-day
to-time = today * one-day + one-day


(err, res) <- db.IOSEvents.aggregate do
	[
		{
			$match:
				"device.adId": $exists: 1
				timeDelta: $exists: 1
				serverTime: $gte: from-time, $lte: to-time
				country: {$exists: 1, $in: ['CA', 'IE']}
				#"event.name": "transition"
				#"event.toView.name": $in: (Obj.keys depths)
		}
		{
			$project:
				adId: "$device.adId"
				timeDelta: 1

				# days passed since installation
				daysAfterInstallation: $subtract: [$divide: ["$timeDelta", one-day], {$mod: [$divide: ["$timeDelta", one-day], 1]}]
				
				eventDate: $subtract: ["$serverTime", "$timeDelta"]

				view: "$event.toView.name"
		}
		{
			$project:
				adId: 1
				daysAfterInstallation: 1
				installationDate: $subtract: ["$eventDate", "$daysAfterInstallation"]
				view: 1
		}
		{
			$project:
				adId: 1
				daysAfterInstallation: 1
				installationDate: $subtract: [$divide: ["$installationDate", one-day], {$mod: [$divide: ["$installationDate", one-day], 1]}]
				view: 1
		}
		{
			$group:
				_id: 
					daysAfterInstallation: "$daysAfterInstallation"
					installationDate: "$installationDate"
					view: "$view"
				users: $addToSet: "$adId"
		}
		{
			$unwind: "$users"
		}
		{
			$group:
				_id: 
					daysAfterInstallation: "$_id.daysAfterInstallation"
					installationDate: "$_id.installationDate"
					view: "$_id.view"
				users: $sum: 1
				#indies: $push: "$users"
		}
		{
			$group:
				_id: "$_id.installationDate"
				values: 
					$push: 
						daysAfterInstallation: "$_id.daysAfterInstallation"
						view: "$_id.view"
						users: "$users"
						#indies: "$indies"
		}
	]


console.log err if !!err



res = res |> sort-by (._id) |> map (-> {day:it._id} <<< (values: it.values |> sort-by (.daysAfterInstallation)) )

# console.log <| JSON.stringify res, null, 2
# return

console.log <| [0 to 10] |> map (j) ->
		[base, users] = res 
			|> filter (({day, values}) -> day <= today - j) 
			|> concat-map (.values)
			|> foldl do 
				([base, usage], {daysAfterInstallation, view, users}) ->
					view = "Others" if not view or view == ""
					usage[view] = 0 if not usage[view]
						
					[
						* base + if daysAfterInstallation == 0 and "Home" == view then users else 0
						* usage <<< (usage[view] += if daysAfterInstallation == j then users else 0)
					]
				[0, {}]
		{day: j, base, users} # , ratio: users/base}

db.close!
