{
    promises: {
        promise-monad
        new-promise
    }
} = require \async-ls
{map, sort, sort-by, mean, fold, find-index, reverse, zip-all-with} = require \prelude-ls

one-day = 86400000
one-minute = 60 * 1000

fill-in-the-gaps = (timezone, query-from, query-to, initial, days) -->

    query-from += timezone * one-minute
    query-to += timezone * one-minute

    empty-list = [query-from til query-to by one-day]  |> map -> {day: (it - it % one-day) / one-day} <<< initial

    days |> fold ((memo, value)->         
        index = empty-list |> find-index -> it.day == value._id
        memo[index] = memo[index] <<< value if index != -1
        memo
    ),  empty-list
    
timestamp-to-day = (key)->
    $divide: [$subtract: [key, $mod: [key, one-day]], one-day]

device-country-filter = (db, countries, callback)->
    db.IOSUsers.aggregate do 
        [
            {
                $match:
                    country: $in: countries
            }
            {
                $project:
                    adId: "$device.adId"
            }
        ]
        (err, result)->
            return callback err, null if err != null
            callback null, (result |> map (.adId))

daily-push-transmit = (db, timezone, query-from, query-to, countries, callback)->    
    (err, devices) <- device-country-filter db, countries    
    db.IOSPushNotifications.aggregate do 
        [
            {
                $match: 
                    "device.adId": $in: devices
                    creationTimestamp: $gt: query-from, $lt: query-to
                    status: "transmitted"
            }
            {
                $project:
                    dubaiCreationTimestamp: $add: ["$creationTimestamp", timezone * one-minute]
            }
            {
                $project: 
                    day: timestamp-to-day "$dubaiCreationTimestamp"
            }
            {
                $group:
                    _id: "$day"
                    count: $sum: 1
            }
        ]
        (err, result)->            
            return callback err, null if err != null                
            callback null, (result |> (fill-in-the-gaps timezone, query-from, query-to, {count: 0}))

daily-push-bounce = (db, timezone, query-from, query-to, countries, callback)->
    db.IOSUsers.aggregate do 
        [
            {
                $match: 
                    country: $in: countries            
                    lastUninstallTime: $gt: query-from, $lt: query-to        
            }
            {
                $project:
                    creationTimestamp: 1
                    dubaiLastUninstallTime: $add: ["$lastUninstallTime", timezone * one-minute]
                    lastUninstallTime: 1
            }
            {
                $project:
                    uninstalled: $gt: ["$lastUninstallTime", "$creationTimestamp"]
                    uninstallDay: timestamp-to-day "$dubaiLastUninstallTime"
            }
            {
                $match:
                    uninstalled: true                    
            }
            {
                $group:
                    _id: "$uninstallDay"
                    count: $sum: 1
            }
        ]
        (err, result)->
            return callback err, null if err != null
            callback null, (result |> (fill-in-the-gaps timezone, query-from, query-to, {count: 0}))

daily-push-received = (db, timezone, query-from, query-to, countries, callback)->
    db.IOSEvents.aggregate do
        [
            {
                $match:
                    country: $in: countries
                    serverTime: $gt: query-from, $lt: query-to
                    "event.name": "pushNotificationReceived"
            }
            {
                $project:
                    dubaiTime: $add: ["$serverTime", timezone * one-minute]
            }
            {
                $project:
                    day: timestamp-to-day "$dubaiTime"
            }
            {
                $group:
                    _id: "$day"
                    count: $sum: 1
            }
        ]
        (err, result) ->
            return callback err, null if err != null
            callback null, (result |> (fill-in-the-gaps timezone, query-from, query-to, {count: 0}))

query = (db, timezone, query-from, query-to, countries = null, sample-from = null, sample-to = null) ->   

    (success, reject) <- new-promise    

    (err, transmitted) <- daily-push-transmit db, timezone, query-from, query-to, countries        
    return reject err if err != null    

    (err, bounced) <- daily-push-bounce db, timezone, query-from, query-to, countries    
    return reject err if err != null

    (err, received) <- daily-push-received db, timezone, query-from, query-to, countries    
    return reject err if err != null

    success <| zip-all-with ((t, b, r)->
        day: t.day, transmitted: t.count, bounced: b.count, received: r.count
    ), transmitted, bounced, received

module.exports = query





