_ = require 'underscore-plus'
{CompositeDisposable} = require 'atom'

module.exports =
class MatchManager
  smartQuotePairs:
    "“": "”"
    '‘': '’'
    "«": "»"
    "‹": "›"

  appendPair: (pairList, [itemLeft, itemRight]) ->
    newPair = {}
    newPair[itemLeft] = itemRight
    pairList = _.extend(pairList, newPair)

  processAutoPairs: (autocompletePairs, pairedList, dataFun) ->
    if autocompletePairs.length
      for autocompletePair in autocompletePairs
        pairArray = autocompletePair.split ''
        @appendPair(pairedList, dataFun(pairArray))

  toggleQuotes: (includeSmartQuotes) ->
    if includeSmartQuotes
      @pairedCharacters = _.extend(@pairedCharacters, @smartQuotePairs)

  updateConfig: ->
    @pairedCharacters = {}
    @pairedCharactersInverse = {}
    @pairRegexes = {}
    @pairsToIndent = {}
    @processAutoPairs(@getScopedSetting('bracket-matcher.autocompleteCharacters'), @pairedCharacters, ((x) -> return [x[0], x[1]]) )
    @toggleQuotes(@getScopedSetting('bracket-matcher.autocompleteSmartQuotes'))
    @processAutoPairs(@getScopedSetting('bracket-matcher.autocompleteCharacters'), @pairedCharactersInverse, ((x) -> return [x[1], x[0]]) )
    @processAutoPairs(@getScopedSetting('bracket-matcher.pairsToIndent'), @pairsToIndent, ((x) -> return [x[0], x[1]]) )
    for startPair, endPair of @pairedCharacters
      @pairRegexes[startPair] = new RegExp("[#{_.escapeRegExp(startPair + endPair)}]", 'g')

  getScopedSetting: (key) ->
    atom.config.get(key, scope: @editor.getRootScopeDescriptor())

  constructor: (@editor, editorElement) ->
    @subscriptions = new CompositeDisposable

    @updateConfig()

    # Subscribe to config changes
    @subscriptions.add atom.config.observe 'bracket-matcher.autocompleteBrackets', {scope: @editor.getRootScopeDescriptor()}, (newConfig) =>
      @updateConfig()
    @subscriptions.add atom.config.observe 'bracket-matcher.autocompleteSmartQuotes', {scope: @editor.getRootScopeDescriptor()}, (newConfig) =>
      @updateConfig()
    @subscriptions.add atom.config.observe 'bracket-matcher.wrapSelectionsInBrackets', {scope: @editor.getRootScopeDescriptor()}, (newConfig) =>
      @updateConfig()
    @subscriptions.add atom.config.observe 'bracket-matcher.autocompleteCharacters', {scope: @editor.getRootScopeDescriptor()}, (newConfig) =>
      @updateConfig()
    @subscriptions.add atom.config.observe 'bracket-matcher.pairsToIndent', {scope: @editor.getRootScopeDescriptor()}, (newConfig) =>
      @updateConfig()

  destroy: =>
    @subscriptions.dispose()
