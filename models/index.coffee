global['mongoose'] = require "./common.coffee"

upperCamelCase = require "uppercamelcase"
requireDicrectory = require "require-directory"

backlist = /common.coffee$/
remap = (name) ->
  upperCamelCase name

module.exports = requireDicrectory module, exclude: backlist, rename: remap
