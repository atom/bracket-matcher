_ = require 'underscore-plus'
{Subscriber} = require 'emissary'

module.exports =
class BracketMatcher
  Subscriber.includeInto(this)

  pairedCharacters:
    '(': ')'
    '[': ']'
    '{': '}'
    '"': '"'
    "'": "'"

  constructor: (editorView) ->
    {@editor} = editorView
    @bracketMarkers = []

    _.adviseBefore(@editor, 'insertText', @insertText)
    _.adviseBefore(@editor, 'insertNewline', @insertNewline)
    _.adviseBefore(@editor, 'backspace', @backspace)

    @subscribe editorView.command 'bracket-matcher:remove-brackets-from-selection', (event) =>
      event.abortKeyBinding() unless @removeBrackets()

    @subscribe @editor, 'destroyed', => @unsubscribe()

  insertText: (text, options) =>
    return true if options?.select or options?.undo is 'skip'
    return false if @isOpeningBracket(text) and @wrapSelectionInBrackets(text)
    return true if @editor.hasMultipleCursors()

    cursorBufferPosition = @editor.getCursorBufferPosition()
    previousCharacter = @editor.getTextInBufferRange([cursorBufferPosition.add([0, -1]), cursorBufferPosition])
    nextCharacter = @editor.getTextInBufferRange([cursorBufferPosition, cursorBufferPosition.add([0,1])])

    hasWordAfterCursor = /\w/.test(nextCharacter)
    hasWordBeforeCursor = /\w/.test(previousCharacter)
    hasQuoteBeforeCursor = previousCharacter is text[0]

    autoCompleteOpeningBracket = @isOpeningBracket(text) and not hasWordAfterCursor and not (@isQuote(text) and (hasWordBeforeCursor or hasQuoteBeforeCursor))
    skipOverExistingClosingBracket = false
    if @isClosingBracket(text) and nextCharacter == text
      if bracketMarker = _.find(@bracketMarkers, (marker) => marker.isValid() and marker.getBufferRange().end.isEqual(cursorBufferPosition))
        skipOverExistingClosingBracket = true

    if skipOverExistingClosingBracket
      bracketMarker.destroy()
      _.remove(@bracketMarkers, bracketMarker)
      @editor.moveCursorRight()
      false
    else if autoCompleteOpeningBracket
      @editor.insertText(text + @pairedCharacters[text])
      @editor.moveCursorLeft()
      range = [cursorBufferPosition, cursorBufferPosition.add([0, text.length])]
      @bracketMarkers.push @editor.markBufferRange(range)
      false

  insertNewline: =>
    return if @editor.hasMultipleCursors()
    return unless @editor.getSelection().isEmpty()

    cursorBufferPosition = @editor.getCursorBufferPosition()
    previousCharacter = @editor.getTextInBufferRange([cursorBufferPosition.add([0, -1]), cursorBufferPosition])
    nextCharacter = @editor.getTextInBufferRange([cursorBufferPosition, cursorBufferPosition.add([0,1])])
    if @pairedCharacters[previousCharacter] is nextCharacter
      @editor.transact =>
        @editor.insertText "\n\n"
        @editor.moveCursorUp()
        cursorRow = @editor.getCursorBufferPosition().row
        @editor.autoIndentBufferRows(cursorRow, cursorRow + 1)
      false

  backspace: =>
    return if @editor.hasMultipleCursors()
    return unless @editor.getSelection().isEmpty()

    cursorBufferPosition = @editor.getCursorBufferPosition()
    previousCharacter = @editor.getTextInBufferRange([cursorBufferPosition.add([0, -1]), cursorBufferPosition])
    nextCharacter = @editor.getTextInBufferRange([cursorBufferPosition, cursorBufferPosition.add([0,1])])
    if @pairedCharacters[previousCharacter] is nextCharacter
      @editor.transact =>
        @editor.moveCursorLeft()
        @editor.delete()
        @editor.delete()
      false

  removeBrackets: ->
    editor = atom.workspace.getActiveEditor()
    bracketsRemoved = false
    editor.mutateSelectedText (selection) =>

      if selection.isEmpty() || !@selectionIsWrappedByMatchingBrackets(selection)
        return

      range = selection.getBufferRange()
      options = isReversed: selection.isReversed()
      selectionStart = range.start
      if range.start.row is range.end.row
        selectionEnd = range.end.add([0, -2])
      else
        selectionEnd = range.end.add([0, -1])

      text = selection.getText()
      selection.insertText(text.substring(1, text.length - 1))
      selection.setBufferRange([selectionStart, selectionEnd], options)
      bracketsRemoved = true
    bracketsRemoved

  wrapSelectionInBrackets: (bracket) ->
    pair = @pairedCharacters[bracket]
    selectionWrapped = false
    @editor.mutateSelectedText (selection) ->
      return if selection.isEmpty()

      selectionWrapped = true
      range = selection.getBufferRange()
      options = isReversed: selection.isReversed()
      selection.insertText("#{bracket}#{selection.getText()}#{pair}")
      selectionStart = range.start.add([0, 1])
      if range.start.row is range.end.row
        selectionEnd = range.end.add([0, 1])
      else
        selectionEnd = range.end
      selection.setBufferRange([selectionStart, selectionEnd], options)

    selectionWrapped

  isQuote: (string) ->
    /'|"/.test(string)

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
    lastCharacter = selectedText[ selectedText.length - 1 ]
    @pairedCharacters[firstCharacter] is lastCharacter
