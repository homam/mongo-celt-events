{map, sort-by, flatten} = require \prelude-ls
db = require \./config .connect!

reduce-f = (key, values) ->

        one-day =  1000*60*60*24
        flatten = (xs) ->
          xs.reduce((acc, a) ->
            if !!a.map and !!a.forEach
              acc ++ flatten a
            else
              acc ++ [a]
          [])


        last = (xs) -> xs[xs.length - 1]

        vs = flatten(values.map(-> it.arr)).sort((a,b) -> a - b).reduce do
                (acc, a) ->
                        return [a] if acc.length == 0
                        if (a - (last acc))  > one-day
                                acc ++ [a]
                        else
                                print <| a - (last acc)
                                print <| JSON.stringify {a:a, acc:acc}
                                acc
                []
        {arr: vs}

query = (callback) ->
        db.IOSEvents.map-reduce do
                ->
                        key = this.device?.adId
                        emit key, {arr: [this.serverTime]}
                reduce-f
                {out: {inline: 1}, query: {"event.name": "transition", "event.toView.name": "Flashcard", "device.adId": {$exists:1}, "serverTime": {$exists:1}}}
                callback

(err, res) <- query
console.log "Error", err if !!err
console.log <| res |> map (r) -> {_id: r._id, visits: r.value.arr |> flatten >> (.length) }

db.close!