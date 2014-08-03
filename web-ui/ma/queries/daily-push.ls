{
    promises: {
        promise-monad
        new-promise
    }
} = require \async-ls
extend = require \deep-extend
{map, sort, sort-by, mean, fold, find-index, reverse, zip-all-with} = require \prelude-ls


one-hour = 1000*60*60
one-day =  one-hour*24

fill-in-the-gaps = (query-from, query-to, initial, days) -->

    empty-list = [query-from to query-to by 86400000]  |> map -> extend {day: (it - it % 86400000) / 86400000}, initial

    days |> fold ((memo, value)->         
        index = empty-list |> find-index -> it.day == value._id
        memo[index] = value if !!index
        memo
    ),  empty-list
    
timestamp-to-day = (key)->
    $divide: [$subtract: [key, $mod: [key, 86400000]], 86400000]

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

daily-push-transmit = (db, query-from, query-to, countries, callback)->
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
                    day: $divide: [$subtract: ["$creationTimestamp", $mod: ["$creationTimestamp", 86400000]], 86400000]
            }
            {
                $group:
                    _id: "$day"
                    count: $sum: 1
            }
        ]
        (err, result)->
            return callback err, null if err != null                
            callback null, (result |> (fill-in-the-gaps query-from, query-to, {count: 0}))

daily-push-bounce = (db, query-from, query-to, countries, callback)->
    db.IOSUsers.aggregate do 
        [
            {
                $match: 
                    country: $in: countries
                    creationTimestamp: $gt: query-from, $lt: query-to
            }
            {
                $project:
                    uninstalled: $gt: ["$lastUninstallTime", "$creationTimestamp"]
                    uninstallDay: timestamp-to-day "$lastUninstallTime"
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
            callback null, (result |> (fill-in-the-gaps query-from, query-to, {count: 0}))

daily-push-received = (db, query-from, query-to, countries, callback)->
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
                    day: timestamp-to-day "$serverTime"
            }
            {
                $group:
                    _id: "$day"
                    count: $sum: 1
            }
        ]
        (err, result) ->
            return callback err, null if err != null
            callback null, (result |> (fill-in-the-gaps query-from, query-to, {count: 0}))

query = (db, query-from, query-to, countries = null, sample-from = null, sample-to = null) ->   
    (success, reject) <- new-promise
    
    query-from -= (new Date()).getTimezoneOffset() * 60000
    query-to -= (new Date()).getTimezoneOffset() * 60000

    (err, transmitted) <- daily-push-transmit db, query-from, query-to, countries
    return reject err if err != null

    (err, bounced) <- daily-push-bounce db, query-from, query-to, countries    
    return reject err if err != null

    (err, received) <- daily-push-received db, query-from, query-to, countries    
    return reject err if err != null

    success <| zip-all-with ((t, b, r)->
        day: t.day, transmitted: t.count, bounced: b.count, received: r.count
    ), transmitted, bounced, received

module.exports = query