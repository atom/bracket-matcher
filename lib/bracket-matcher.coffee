{_} = require 'atom'
BracketMatcherView = require './bracket-matcher-view'

module.exports =
  pairedCharacters:
    '(': ')'
    '[': ']'
    '{': '}'
    '"': '"'
    "'": "'"

  activate: ->
    rootView.eachEditor (editor) =>
      new BracketMatcherView(editor) if editor.attached and editor.getPane()?

    rootView.eachEditSession (editSession) => @subscribeToEditSession(editSession)

  subscribeToEditSession: (editSession) ->
    @bracketMarkers = []

    _.adviseBefore editSession, 'insertText', (text) =>
      return true if editSession.hasMultipleCursors()

      cursorBufferPosition = editSession.getCursorBufferPosition()
      previousCharacter = editSession.getTextInBufferRange([cursorBufferPosition.add([0, -1]), cursorBufferPosition])
      nextCharacter = editSession.getTextInBufferRange([cursorBufferPosition, cursorBufferPosition.add([0,1])])

      if @isOpeningBracket(text) and not editSession.getSelection().isEmpty()
        @wrapSelectionInBrackets(editSession, text)
        return false

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
        editSession.moveCursorRight()
        false
      else if autoCompleteOpeningBracket
        editSession.insertText(text + @pairedCharacters[text])
        editSession.moveCursorLeft()
        range = [cursorBufferPosition, cursorBufferPosition.add([0, text.length])]
        @bracketMarkers.push editSession.markBufferRange(range)
        false

    _.adviseBefore editSession, 'backspace', =>
      return if editSession.hasMultipleCursors()
      return unless editSession.getSelection().isEmpty()

      cursorBufferPosition = editSession.getCursorBufferPosition()
      previousCharacter = editSession.getTextInBufferRange([cursorBufferPosition.add([0, -1]), cursorBufferPosition])
      nextCharacter = editSession.getTextInBufferRange([cursorBufferPosition, cursorBufferPosition.add([0,1])])
      if @pairedCharacters[previousCharacter] is nextCharacter
        editSession.transact =>
          editSession.moveCursorLeft()
          editSession.delete()
          editSession.delete()
        false

  wrapSelectionInBrackets: (editSession, bracket) ->
    pair = @pairedCharacters[bracket]
    editSession.mutateSelectedText (selection) =>
      return if selection.isEmpty()

      range = selection.getBufferRange()
      options = isReversed: selection.isReversed()
      selection.insertText("#{bracket}#{selection.getText()}#{pair}")
      selectionStart = range.start.add([0, 1])
      if range.start.row is range.end.row
        selectionEnd = range.end.add([0, 1])
      else
        selectionEnd = range.end
      selection.setBufferRange([selectionStart, selectionEnd], options)

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
