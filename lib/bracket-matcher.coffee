_ = require 'underscore-plus'
{CompositeDisposable} = require 'atom'
SelectorCache = require './selector-cache'

module.exports =
class BracketMatcher
  pairsToIndent:
    '(': ')'
    '[': ']'
    '{': '}'

  defaultPairs:
    '(': ')'
    '[': ']'
    '{': '}'
    '"': '"'
    "'": "'"
    '`': '`'

  smartQuotePairs:
    "“": "”"
    '‘': '’'
    "«": "»"
    "‹": "›"

  toggleQuotes: (includeSmartQuotes) ->
    if includeSmartQuotes
      @pairedCharacters = _.extend({}, @defaultPairs, @smartQuotePairs)
    else
      @pairedCharacters = @defaultPairs

  excludePairs: (excludePairs) ->
    if excludePairs.length
      for excludePair in excludePairs
        pairArray = excludePair.split ':'
        @pairedCharacters = _.omit(@pairedCharacters, pairArray[0])

  addPairs: (addPairs) ->
    if addPairs.length
      for addPair in addPairs
        pairArray = addPair.split ':'
        newPair = {}
        newPair[pairArray[0]] = pairArray[1]
        @pairedCharacters = _.extend(@pairedCharacters, newPair)

  updateConfig: ->
    @toggleQuotes(@getScopedSetting('bracket-matcher.autocompleteSmartQuotes'))
    @excludePairs(@getScopedSetting('bracket-matcher.excludePairs'))
    @addPairs(@getScopedSetting('bracket-matcher.addPairs'))

  constructor: (@editor, editorElement) ->
    @subscriptions = new CompositeDisposable
    @bracketMarkers = []

    _.adviseBefore(@editor, 'insertText', @insertText)
    _.adviseBefore(@editor, 'insertNewline', @insertNewline)
    _.adviseBefore(@editor, 'backspace', @backspace)

    @updateConfig()

    @subscriptions.add atom.commands.add editorElement, 'bracket-matcher:remove-brackets-from-selection', (event) =>
      event.abortKeyBinding() unless @removeBrackets()

    @subscriptions.add @editor.onDidDestroy => @unsubscribe()

    # Subscribe to config changes
    @subscriptions.add atom.config.observe 'bracket-matcher.autocompleteBrackets', {scope: @editor.getRootScopeDescriptor()}, (newConfig) =>
      @updateConfig()
    @subscriptions.add atom.config.observe 'bracket-matcher.autocompleteSmartQuotes', {scope: @editor.getRootScopeDescriptor()}, (newConfig) =>
      @updateConfig()
    @subscriptions.add atom.config.observe 'bracket-matcher.wrapSelectionsInBrackets', {scope: @editor.getRootScopeDescriptor()}, (newConfig) =>
      @updateConfig()
    @subscriptions.add atom.config.observe 'bracket-matcher.excludePairs', {scope: @editor.getRootScopeDescriptor()}, (newConfig) =>
      @updateConfig()
    @subscriptions.add atom.config.observe 'bracket-matcher.addPairs', {scope: @editor.getRootScopeDescriptor()}, (newConfig) =>
      @updateConfig()

  insertText: (text, options) =>
    return true unless text
    return true if options?.select or options?.undo is 'skip'

    return false if @wrapSelectionInBrackets(text)
    return true if @editor.hasMultipleCursors()

    cursorBufferPosition = @editor.getCursorBufferPosition()
    previousCharacters = @editor.getTextInBufferRange([cursorBufferPosition.traverse([0, -2]), cursorBufferPosition])
    nextCharacter = @editor.getTextInBufferRange([cursorBufferPosition, cursorBufferPosition.traverse([0, 1])])

    previousCharacter = previousCharacters.slice(-1)

    hasWordAfterCursor = /\w/.test(nextCharacter)
    hasWordBeforeCursor = /\w/.test(previousCharacter)
    hasQuoteBeforeCursor = previousCharacter is text[0]
    hasEscapeSequenceBeforeCursor = previousCharacters.match(/\\/g)?.length >= 1 # To guard against the "\\" sequence

    if text is '#' and @isCursorOnInterpolatedString()
      autoCompleteOpeningBracket = @getScopedSetting('bracket-matcher.autocompleteBrackets') and not hasEscapeSequenceBeforeCursor
      text += '{'
      pair = '}'
    else
      autoCompleteOpeningBracket = @getScopedSetting('bracket-matcher.autocompleteBrackets') and @isOpeningBracket(text) and not hasWordAfterCursor and not (@isQuote(text) and (hasWordBeforeCursor or hasQuoteBeforeCursor)) and not hasEscapeSequenceBeforeCursor
      pair = @pairedCharacters[text]

    skipOverExistingClosingBracket = false
    if @isClosingBracket(text) and nextCharacter is text and not hasEscapeSequenceBeforeCursor
      if bracketMarker = _.find(@bracketMarkers, (marker) -> marker.isValid() and marker.getBufferRange().end.isEqual(cursorBufferPosition))
        skipOverExistingClosingBracket = true

    if skipOverExistingClosingBracket
      bracketMarker.destroy()
      _.remove(@bracketMarkers, bracketMarker)
      @editor.moveRight()
      false
    else if autoCompleteOpeningBracket
      @editor.insertText(text + pair)
      @editor.moveLeft()
      range = [cursorBufferPosition, cursorBufferPosition.traverse([0, text.length])]
      @bracketMarkers.push @editor.markBufferRange(range)
      false

  insertNewline: =>
    return if @editor.hasMultipleCursors()
    return unless @editor.getLastSelection().isEmpty()

    cursorBufferPosition = @editor.getCursorBufferPosition()
    previousCharacters = @editor.getTextInBufferRange([cursorBufferPosition.traverse([0, -2]), cursorBufferPosition])
    nextCharacter = @editor.getTextInBufferRange([cursorBufferPosition, cursorBufferPosition.traverse([0, 1])])

    previousCharacter = previousCharacters.slice(-1)

    hasEscapeSequenceBeforeCursor = previousCharacters.match(/\\/g)?.length >= 1 # To guard against the "\\" sequence
    if @pairsToIndent[previousCharacter] is nextCharacter and not hasEscapeSequenceBeforeCursor
      @editor.transact =>
        @editor.insertText "\n\n"
        @editor.moveUp()
        if @getScopedSetting('editor.autoIndent')
          cursorRow = @editor.getCursorBufferPosition().row
          @editor.autoIndentBufferRows(cursorRow, cursorRow + 1)
      false

  backspace: =>
    return if @editor.hasMultipleCursors()
    return unless @editor.getLastSelection().isEmpty()

    cursorBufferPosition = @editor.getCursorBufferPosition()
    previousCharacters = @editor.getTextInBufferRange([cursorBufferPosition.traverse([0, -2]), cursorBufferPosition])
    nextCharacter = @editor.getTextInBufferRange([cursorBufferPosition, cursorBufferPosition.traverse([0, 1])])

    previousCharacter = previousCharacters.slice(-1)

    hasEscapeSequenceBeforeCursor = previousCharacters.match(/\\/g)?.length >= 1 # To guard against the "\\" sequence
    if (@pairedCharacters[previousCharacter] is nextCharacter) and not hasEscapeSequenceBeforeCursor and @getScopedSetting('bracket-matcher.autocompleteBrackets')
      @editor.transact =>
        @editor.moveLeft()
        @editor.delete()
        @editor.delete()
      false

  removeBrackets: ->
    bracketsRemoved = false
    @editor.mutateSelectedText (selection) =>
      return unless @selectionIsWrappedByMatchingBrackets(selection)

      range = selection.getBufferRange()
      options = reversed: selection.isReversed()
      selectionStart = range.start
      if range.start.row is range.end.row
        selectionEnd = range.end.traverse([0, -2])
      else
        selectionEnd = range.end.traverse([0, -1])

      text = selection.getText()
      selection.insertText(text.substring(1, text.length - 1))
      selection.setBufferRange([selectionStart, selectionEnd], options)
      bracketsRemoved = true
    bracketsRemoved

  wrapSelectionInBrackets: (bracket) ->
    return false unless @getScopedSetting('bracket-matcher.wrapSelectionsInBrackets')

    if bracket is '#'
      return false unless @isCursorOnInterpolatedString()
      bracket = '#{'
      pair = '}'
    else
      return false unless @isOpeningBracket(bracket)
      pair = @pairedCharacters[bracket]

    selectionWrapped = false
    @editor.mutateSelectedText (selection) ->
      return if selection.isEmpty()

      # Don't wrap in #{} if the selection spans more than one line
      return if bracket is '#{' and not selection.getBufferRange().isSingleLine()

      selectionWrapped = true
      range = selection.getBufferRange()
      options = reversed: selection.isReversed()
      selection.insertText("#{bracket}#{selection.getText()}#{pair}")
      selectionStart = range.start.traverse([0, bracket.length])
      if range.start.row is range.end.row
        selectionEnd = range.end.traverse([0, bracket.length])
      else
        selectionEnd = range.end
      selection.setBufferRange([selectionStart, selectionEnd], options)

    selectionWrapped

  isQuote: (string) ->
    /['"`]/.test(string)

  isCursorOnInterpolatedString: ->
    unless @interpolatedStringSelector?
      segments = [
        '*.*.*.interpolated.ruby'
        'string.interpolated.ruby'
        'string.regexp.interpolated.ruby'
        'string.quoted.double.coffee'
        'string.unquoted.heredoc.ruby'
        'string.quoted.double.livescript'
        'string.quoted.double.heredoc.livescript'
        'string.quoted.double.elixir'
        'string.quoted.double.heredoc.elixir'
        'comment.documentation.heredoc.elixir'
      ]
      @interpolatedStringSelector = SelectorCache.get(segments.join(' | '))
    @interpolatedStringSelector.matches(@editor.getLastCursor().getScopeDescriptor().getScopesArray())

  getInvertedPairedCharacters: ->
    return @invertedPairedCharacters if @invertedPairedCharacters

    @invertedPairedCharacters = {}
    for open, close of @pairedCharacters
      @invertedPairedCharacters[close] = open
    @invertedPairedCharacters

  isOpeningBracket: (string) ->
    @pairedCharacters.hasOwnProperty(string)

  isClosingBracket: (string) ->
    @getInvertedPairedCharacters().hasOwnProperty(string)

  selectionIsWrappedByMatchingBrackets: (selection) ->
    return false if selection.isEmpty()
    selectedText = selection.getText()
    firstCharacter = selectedText[0]
    lastCharacter = selectedText[selectedText.length - 1]
    @pairedCharacters[firstCharacter] is lastCharacter

  unsubscribe: ->
    @subscriptions.dispose()

  getScopedSetting: (key) ->
    atom.config.get(key, scope: @editor.getRootScopeDescriptor())
