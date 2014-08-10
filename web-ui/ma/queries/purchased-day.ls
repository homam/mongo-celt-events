{
    promises: {
        promise-monad
        new-promise
    }
} = require \async-ls
{map, sort, sort-by, mean, filter, first, group-by, concat-map, foldl, maximum} = require \prelude-ls
utils = require "./utils"

query = (db, query-from, query-to, countries = null, sample-from = null, sample-to = null, sources = null, callback) ->
    (success, reject) <- new-promise
    (err, devices) <- utils.get-devices-from-media-sources db, sources

    query-from -= (new Date()).getTimezoneOffset() * 60000
    query-to -= (new Date()).getTimezoneOffset() * 60000

    db.IOSEvents.aggregate do
        [
            {
                $match:
                    "event.name": "IAP-PurchaseVerified"
                    "event.valid": true
                    country: "$in": countries
                    "device.adId": 
                        {"$nin": ["7E62EADB-5D74-4D72-847E-58FE4170BAAE", "DEA50A76-B90C-40D8-B7B8-40363F18AAED"]} <<< if !!devices then "$in": devices
                    serverTime: $gte: query-from, $lte: query-to
            },
            {
                $project:
                    serverTime: "$serverTime"
                    day: "$divide": [{"$subtract": ["$timeDelta", {"$mod": ["$timeDelta", 86400000]}]}, 86400000]
                    adId: "$device.adId"
                    installationTime: $subtract: ["$serverTime", "$timeDelta"]
            }
        ] ++ (
            if !!sample-to && !!sample-from        
                [
                    $match:                            
                        installationTime: $gte: sample-from, $lte: sample-to                    
                ]
            else 
                []
        ) ++ [
            {
                $group:
                    _id: "$adId",
                    firstSubscriptionDay: "$first": "$day"
                    firstSubscriptionTimestamp: "$first": "$serverTime"
            },
            {
                $group:
                    _id: "$firstSubscriptionDay"
                    userSubscription: "$sum": 1
            }
        ]
        (err, res) ->
            return reject err if !!err
            success <| res

module.exports = query