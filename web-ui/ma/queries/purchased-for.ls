{
    promises: {
        promise-monad
        new-promise
        bindP
        serial-map
        parallel-map
        fmapP
    }    
} = require \async-ls
{map, sort, sort-by, mean, fold, find, find-index, reverse} = require \prelude-ls
utils = require "./utils"

courses = require \../data/courses.json

paid-users = (db, query-from, query-to, countries = null, sample-from = null, sample-to = null, devices, callback)->
    (success, reject) <- new-promise
    (err, results) <- db.IOSEvents.aggregate do 
        [
            {
                $match:
                    country: $in: countries
                    "event.name": "IAP-Purchased"
                    "device.adId": {$exists: 1} <<< if !!devices then $in: devices else {}
            }
            {
                $group:
                    _id: "$device.adId"
                    timeDelta: $first: "$timeDelta"
            }
        ]    
    return  reject err if !!err
    console.log "list of paid users: #{JSON.stringify(results, null, 1)}"
    success <| results


purchased-for = (db, adId, timeDelta)-> 
    (success, reject) <- new-promise
    (err, results) <- db.IOSEvents.aggregate do
        [
            {
                $match:
                    "device.adId": adId
                    timeDelta: $lt: timeDelta
            }
            {
                $sort:
                    _id: -1
            }
            {
                $match:
                    "event.toView.name": "Subscription"
            }
            {
                $limit: 1
            }
            {
                $project:
                    courseKey: "$event.fromView.courseKey"
            }
        ]
    return reject err if !!err
    console.log "#{adId} purchased for #{results[0].courseKey}"
    success <| results[0] <<< adId: adId

query = (db, timezone, query-from, query-to, countries = null, sample-from = null, sample-to = null, sources = null)->

    (success, reject) <- new-promise
    (err, devices) <- utils.get-devices-from-media-sources db, sources

    console.log "getting paid users"

    (paid-users db, query-from, query-to, countries, sample-from, sample-to, devices)  
        |> fmapP -> 
            it 
                |> parallel-map ({_id, timeDelta})-> purchased-for db, _id, timeDelta
                |> fmapP ->
                    it 
                        |> map ({adId, courseKey})->                             
                            courses |> find (-> courseKey == it.key) |> (?.title?.en)
                        |> fold ((m, v)-> 
                            if !m[v]
                                m[v] = 0
                            m[v]++
                            m
                        ), {}
                        |> success
                
                

module.exports = query





