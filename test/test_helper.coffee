process.env.NODE_ENV ?= "test"
chai = require 'chai'
expect = chai.expect
models = require('../models')

# Why would you not want this?!
chai.Assertion.includeStack = true

module.exports = {chai, expect, models}
module.exports[k] ?= v for k, v of models
