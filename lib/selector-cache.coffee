ScopeSelector = require('first-mate').ScopeSelector
cache = {}

exports.get = (selector) ->
  scopeSelector = cache[selector]
  unless scopeSelector?
    scopeSelector = new ScopeSelector(selector)
    cache[selector] = scopeSelector
  scopeSelector
