ScopeSelector = null
cache = {}

exports.get = (selector) ->
  scopeSelector = cache[selector]
  unless scopeSelector?
    ScopeSelector ?= require('first-mate').ScopeSelector
    scopeSelector = new ScopeSelector(selector)
    cache[selector] = scopeSelector
  scopeSelector
