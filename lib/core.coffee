Promise = require "bluebird"
_ = require "lodash"
fs = require "fs"
path = require "path"
util = require "util"
vm = require "vm"
nodeREPL = require "repl"

CoffeeScript = require "coffee-script"
coffeeScriptPath = path.dirname require.resolve("coffee-script")
rootPath = process.cwd()
modelsPath = path.join(rootPath, "models")
unless fs.existsSync modelsPath
  modelsPath = null

replDefaults =
  prompt: "coffee>"
  historyFile: path.join process.env.HOME, '.coffee_history' if process.env.HOME
  historyMaxInputSize: 10240
  eval: (input, context, filename, cb) ->
    input = input.replace /\uFF00/g, '\n'
    input = input.replace /^\(([\s\S]*)\n\)$/m, '$1'

    {Block, Assign, Value, Literal} = require path.join(coffeeScriptPath,"nodes")
    try
      tokens = CoffeeScript.tokens input
      referencedVars = (
        token[1] for token in tokens when token.variable
      )
      ast = CoffeeScript.nodes tokens

      ast = new Block [
        new Assign (new Value new Literal '_'), ast, '='
      ]
      js = ast.compile {bare: yes, locals: Object.keys(context), referencedVars}
      cb null, runInContext js, context, filename
    catch err
      console.log err
      cb err

runInContext = (js, context, filename) ->
  if context is global
    vm.runInThisContext js, filename
  else
    vm.runInContext js, context, filename

addMultilineHandler = (repl) ->
  {rli, inputStream, outputStream} = repl
  origPrompt = repl._prompt ? repl.prompt

  multiline =
    enabled: off
    initialPrompt: origPrompt.replace /^[^> ]*/, (x) -> x.replace /./g, '-'
    prompt: origPrompt.replace /^[^> ]*>?/, (x) -> x.replace /./g, '.'
    buffer: ''

  nodeLineListener = rli.listeners('line')[0]
  rli.removeListener 'line', nodeLineListener
  rli.on 'line', (cmd) ->
    if multiline.enabled
      multiline.buffer += "#{cmd}\n"
      rli.setPrompt multiline.prompt
      rli.prompt true
    else
      rli.setPrompt origPrompt
      nodeLineListener cmd
    return

  inputStream.on 'keypress', (char, key) ->
    return unless key and key.ctrl and not key.meta and not key.shift and key.name is 'v'
    if multiline.enabled
      unless multiline.buffer.match /\n/
        multiline.enabled = not multiline.enabled
        rli.setPrompt origPrompt
        rli.prompt true
        return
      return if rli.line? and not rli.line.match /^\s*$/

      multiline.enabled = not multiline.enabled
      rli.line = ''
      rli.cursor = 0
      rli.output.cursorTo 0
      rli.output.clearLine 1

      multiline.buffer = multiline.buffer.replace /\n/g, '\uFF00'
      rli.emit 'line', multiline.buffer
      multiline.buffer = ''
    else
      multiline.enabled = not multiline.enabled
      rli.setPrompt multiline.initialPrompt
      rli.prompt true
    return

addHistory = (repl, filename, maxSize) ->
  lastLine = null
  try
    stat = fs.statSync filename
    size = Math.min maxSize, stat.size

    readFd = fs.openSync filename, 'r'
    buffer = new Buffer(size)
    fs.readSync readFd, buffer, 0, size, stat.size - size
    fs.close readFd

    repl.rli.history = buffer.toString().split('\n').reverse()
    repl.rli.history.pop() if stat.size > maxSize
    repl.rli.history.shift() if repl.rli.history[0] is ''
    repl.rli.historyIndex = -1
    lastLine = repl.rli.history[0]
  fd = fs.openSync filename, 'a'

  repl.rli.addListener 'line', (code) ->
    if code and code.length and code isnt '.history' and lastLine isnt code
      fs.write fd, "#{code}\n"
      lastLine = code

  repl.on 'exit', -> fs.close fd

  repl.commands[getCommandId(repl, 'history')] =
    help: 'Show command history'
    action: ->
      repl.outputStream.write "#{repl.rli.history[..].reverse().join '\n'}\n"
      repl.displayPrompt()

getCommandId = (repl, commandName) ->
  commandsHaveLeadingDot = repl.commands['.help']?
  if commandsHaveLeadingDot then ".#{commandName}" else commandName

watchModels = (watchedFile, repl) ->
  reload = (event, file) ->
    if /^\.(.*)/.test file
      return

    if /.*~$/.test file
      return

    if /^\d/.test file
      return

    console.log "event: #{event}, #{file} reload!"
    delete require.cache[path.join rootPath, "models/#{file}"]
    delete require.cache[path.join rootPath, "models/index.coffee"]
    repl.context.models = require path.join(rootPath,"models/index.coffee")

  fs.watch(watchedFile, recursive: true).on("change", reload).on("error", (error) ->
    console.log "error = #{error}"
  )

module.exports =
  start: (opts = {}) ->
    [major, minor, build] = process.versions.node.split('.').map (n) -> parseInt(n)

    if major is 0 and minor < 8
      console.warn "Node 0.8.0+ required for CoffeeScript REPL"
      process.exit 1

    CoffeeScript.register()
    process.argv = ['coffee'].concat process.argv[2..]
    opts = _.merge replDefaults, opts
    repl = nodeREPL.start opts
    runInContext opts.prelude, repl.context, 'prelude' if opts.prelude
    repl.on 'exit', -> repl.outputStream.write '\n' if not repl.rli.closed
    addMultilineHandler repl
    addHistory repl, opts.historyFile, opts.historyMaxInputSize if opts.historyFile
    repl.commands[getCommandId(repl, 'load')].help = 'Load code from a file into this REPL session'
    repl.context.models = require modelsPath if modelsPath
    repl.context.lodash = _
    repl.context.Promise = Promise
    _.merge(repl.context, opts.context) if opts.context
    watchModels modelsPath, repl if modelsPath
    repl
