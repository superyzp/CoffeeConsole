# CoffeeConsole

CoffeeConsole类似Rails Console,可以自动引入models，model修改后自动生效，自动引入常用的lodash、bluebird,还可以自定义一些需要引入的库和对象。
***

###如何使用:
1. 使用标准console
    ./bin/console

2. 使用自定义console

```node
   console = require "./lib/core.coffee"
   console.start context:{}
```

