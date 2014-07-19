```Shell
touch config.ls
```

```LiveScript
# 172.30.0.160
connect = ->
	db = require("mongojs").connect \localhost/MA, [\IOSEvents]
	db

exports.connect = connect
```