{CompositeDisposable} = require 'atom'
_ = require 'underscore-plus'
{Range, Point} = require 'atom'
TagFinder = require './tag-finder'

MAX_ROWS_TO_SCAN = 10000
ONE_CHAR_FORWARD_TRAVERSAL = Object.freeze(Point(0, 1))
ONE_CHAR_BACKWARD_TRAVERSAL = Object.freeze(Point(0, -1))
TWO_CHARS_BACKWARD_TRAVERSAL = Object.freeze(Point(0, -2))
MAX_ROWS_TO_SCAN_FORWARD_TRAVERSAL = Object.freeze(Point(MAX_ROWS_TO_SCAN, 0))
MAX_ROWS_TO_SCAN_BACKWARD_TRAVERSAL = Object.freeze(Point(-MAX_ROWS_TO_SCAN, 0))

module.exports =
class BracketMatcherView
  constructor: (@editor, editorElement, @matchManager) ->
    @subscriptions = new CompositeDisposable
    @tagFinder = new TagFinder(@editor)
    @pairHighlighted = false
    @tagHighlighted = false

    @subscriptions.add @editor.onDidTokenize(@updateMatch)
    @subscriptions.add @editor.getBuffer().onDidChangeText(@updateMatch)
    @subscriptions.add @editor.onDidChangeGrammar(@updateMatch)
    @subscriptions.add @editor.onDidChangeSelectionRange(@updateMatch)
    @subscriptions.add @editor.onDidAddCursor(@updateMatch)
    @subscriptions.add @editor.onDidRemoveCursor(@updateMatch)

    @subscriptions.add atom.commands.add editorElement, 'bracket-matcher:go-to-matching-bracket', =>
      @goToMatchingPair()

    @subscriptions.add atom.commands.add editorElement, 'bracket-matcher:go-to-enclosing-bracket', =>
      @goToEnclosingPair()

    @subscriptions.add atom.commands.add editorElement, 'bracket-matcher:select-inside-brackets', =>
      @selectInsidePair()

    @subscriptions.add atom.commands.add editorElement, 'bracket-matcher:close-tag', =>
      @closeTag()

    @subscriptions.add atom.commands.add editorElement, 'bracket-matcher:remove-matching-brackets', =>
      @removeMatchingBrackets()

    @subscriptions.add @editor.onDidDestroy @destroy

    @updateMatch()

  destroy: =>
    @subscriptions.dispose()

  updateMatch: =>
    if @pairHighlighted
      @editor.destroyMarker(@startMarker.id)
      @editor.destroyMarker(@endMarker.id)

    @pairHighlighted = false
    @tagHighlighted = false

    return unless @editor.getLastSelection().isEmpty()

    {position, currentPair, matchingPair} = @findCurrentPair(false)
    if position
      matchPosition = @findMatchingEndPair(position, currentPair, matchingPair)
    else
      {position, currentPair, matchingPair} = @findCurrentPair(true)
      if position
        matchPosition = @findMatchingStartPair(position, matchingPair, currentPair)

    startRange = null
    endRange = null
    highlightTag = false
    highlightPair = false
    if position? and matchPosition?
      startRange = Range(position, position.traverse(ONE_CHAR_FORWARD_TRAVERSAL))
      endRange = Range(matchPosition, matchPosition.traverse(ONE_CHAR_FORWARD_TRAVERSAL))
      highlightPair = true
    else
      if pair = @tagFinder.findMatchingTags()
        startRange = pair.startRange
        endRange = pair.endRange
        highlightPair = true
        highlightTag = true

    return unless highlightTag or highlightPair
    return if @editor.isFoldedAtCursorRow()
    return if @isCursorOnCommentOrString()

    @startMarker = @createMarker(startRange)
    @endMarker = @createMarker(endRange)
    @pairHighlighted = highlightPair
    @tagHighlighted = highlightTag

  removeMatchingBrackets: ->
    return @editor.backspace() if @editor.hasMultipleCursors()

    @editor.transact =>
      @editor.selectLeft() if @editor.getLastSelection().isEmpty()
      text = @editor.getSelectedText()
      @editor.moveRight()

      #check if the character to the left is part of a pair
      if @matchManager.pairedCharacters.hasOwnProperty(text) or @matchManager.pairedCharactersInverse.hasOwnProperty(text)
        {position, currentPair, matchingPair} = @findCurrentPair(false)
        if position
          matchPosition = @findMatchingEndPair(position, currentPair, matchingPair)
        else
          {position, currentPair, matchingPair} = @findCurrentPair(true)
          if position
            matchPosition = @findMatchingStartPair(position, matchingPair, currentPair)

        if position? and matchPosition?
          @editor.setCursorBufferPosition(matchPosition)
          @editor.delete()
          # if on the same line and the cursor is in front of an end pair
          # offset by one to make up for the missing character
          if position.row is matchPosition.row and @matchManager.pairedCharactersInverse.hasOwnProperty(currentPair)
            position = position.traverse(ONE_CHAR_BACKWARD_TRAVERSAL)
          @editor.setCursorBufferPosition(position)
          @editor.delete()
        else
          @editor.backspace()
      else
        @editor.backspace()

  findMatchingEndPair: (startPairPosition, startPair, endPair) ->
    return if startPair is endPair

    scanRange = new Range(
      startPairPosition.traverse(ONE_CHAR_FORWARD_TRAVERSAL),
      startPairPosition.traverse(MAX_ROWS_TO_SCAN_FORWARD_TRAVERSAL)
    )
    endPairPosition = null
    unpairedCount = 0
    @editor.scanInBufferRange @matchManager.pairRegexes[startPair], scanRange, (result) =>
      return if @isRangeCommentedOrString(result.range)
      switch result.match[0]
        when startPair
          unpairedCount++
        when endPair
          unpairedCount--
          if unpairedCount < 0
            endPairPosition = result.range.start
            result.stop()

    endPairPosition

  findMatchingStartPair: (endPairPosition, startPair, endPair) ->
    return if startPair is endPair

    scanRange = new Range(
      endPairPosition.traverse(MAX_ROWS_TO_SCAN_BACKWARD_TRAVERSAL),
      endPairPosition
    )
    startPairPosition = null
    unpairedCount = 0
    @editor.backwardsScanInBufferRange @matchManager.pairRegexes[startPair], scanRange, (result) =>
      return if @isRangeCommentedOrString(result.range)
      switch result.match[0]
        when startPair
          unpairedCount--
          if unpairedCount < 0
            startPairPosition = result.range.start
            result.stop()
        when endPair
          unpairedCount++
    startPairPosition

  findAnyStartPair: (cursorPosition) ->
    scanRange = new Range(Point.ZERO, cursorPosition)
    startPair = _.escapeRegExp(_.keys(@matchManager.pairedCharacters).join(''))
    endPair = _.escapeRegExp(_.keys(@matchManager.pairedCharactersInverse).join(''))
    combinedRegExp = new RegExp("[#{startPair}#{endPair}]", 'g')
    startPairRegExp = new RegExp("[#{startPair}]", 'g')
    endPairRegExp = new RegExp("[#{endPair}]", 'g')
    startPosition = null
    unpairedCount = 0
    @editor.backwardsScanInBufferRange combinedRegExp, scanRange, (result) =>
      return if @isRangeCommentedOrString(result.range)
      if result.match[0].match(endPairRegExp)
        unpairedCount++
      else if result.match[0].match(startPairRegExp)
        unpairedCount--
        if unpairedCount < 0
          startPosition = result.range.start
          result.stop()
     startPosition

  createMarker: (bufferRange) ->
    marker = @editor.markBufferRange(bufferRange)
    @editor.decorateMarker(marker, type: 'highlight', class: 'bracket-matcher', deprecatedRegionClass: 'bracket-matcher')
    marker

  findCurrentPair: (isInverse) ->
    position = @editor.getCursorBufferPosition()
    if isInverse
      matches = @matchManager.pairedCharactersInverse
      position = position.traverse(ONE_CHAR_BACKWARD_TRAVERSAL)
    else
      matches = @matchManager.pairedCharacters
    currentPair = @editor.getTextInRange(Range.fromPointWithDelta(position, 0, 1))
    unless matches[currentPair]
      if isInverse
        position = position.traverse(ONE_CHAR_FORWARD_TRAVERSAL)
      else
        position = position.traverse(ONE_CHAR_BACKWARD_TRAVERSAL)
      currentPair = @editor.getTextInRange(Range.fromPointWithDelta(position, 0, 1))
    if matchingPair = matches[currentPair]
      {position, currentPair, matchingPair}
    else
      {}

  goToMatchingPair: ->
    return @goToEnclosingPair() unless @pairHighlighted
    position = @editor.getCursorBufferPosition()

    if @tagHighlighted
      startRange = @startMarker.getBufferRange()
      tagLength = startRange.end.column - startRange.start.column
      endRange = @endMarker.getBufferRange()
      if startRange.compare(endRange) > 0
        [startRange, endRange] = [endRange, startRange]

      # include the <
      startRange = new Range(startRange.start.traverse(ONE_CHAR_BACKWARD_TRAVERSAL), endRange.end.traverse(ONE_CHAR_BACKWARD_TRAVERSAL))
      # include the </
      endRange = new Range(endRange.start.traverse(TWO_CHARS_BACKWARD_TRAVERSAL), endRange.end.traverse(TWO_CHARS_BACKWARD_TRAVERSAL))

      if position.isLessThan(endRange.start)
        tagCharacterOffset = position.column - startRange.start.column
        tagCharacterOffset++ if tagCharacterOffset > 0
        tagCharacterOffset = Math.min(tagCharacterOffset, tagLength + 2) # include </
        @editor.setCursorBufferPosition(endRange.start.traverse([0, tagCharacterOffset]))
      else
        tagCharacterOffset = position.column - endRange.start.column
        tagCharacterOffset-- if tagCharacterOffset > 1
        tagCharacterOffset = Math.min(tagCharacterOffset, tagLength + 1) # include <
        @editor.setCursorBufferPosition(startRange.start.traverse([0, tagCharacterOffset]))
    else
      previousPosition = position.traverse(ONE_CHAR_BACKWARD_TRAVERSAL)
      startPosition = @startMarker.getStartBufferPosition()
      endPosition = @endMarker.getStartBufferPosition()

      if position.isEqual(startPosition)
        @editor.setCursorBufferPosition(endPosition.traverse(ONE_CHAR_FORWARD_TRAVERSAL))
      else if previousPosition.isEqual(startPosition)
        @editor.setCursorBufferPosition(endPosition)
      else if position.isEqual(endPosition)
        @editor.setCursorBufferPosition(startPosition.traverse(ONE_CHAR_FORWARD_TRAVERSAL))
      else if previousPosition.isEqual(endPosition)
        @editor.setCursorBufferPosition(startPosition)

  goToEnclosingPair: ->
    return if @pairHighlighted

    if matchPosition = @findAnyStartPair(@editor.getCursorBufferPosition())
      @editor.setCursorBufferPosition(matchPosition)
    else if pair = @tagFinder.findEnclosingTags()
      {startRange, endRange} = pair
      if startRange.compare(endRange) > 0
        [startRange, endRange] = [endRange, startRange]
      @editor.setCursorBufferPosition(pair.startRange.start)

  selectInsidePair: ->
    if @pairHighlighted
      startRange = @startMarker.getBufferRange()
      endRange = @endMarker.getBufferRange()

      if startRange.compare(endRange) > 0
        [startRange, endRange] = [endRange, startRange]

      if @tagHighlighted
        startPosition = startRange.end
        endPosition = endRange.start.traverse(TWO_CHARS_BACKWARD_TRAVERSAL) # Don't select </
      else
        startPosition = startRange.start
        endPosition = endRange.start
    else
      if startPosition = @findAnyStartPair(@editor.getCursorBufferPosition())
        startPair = @editor.getTextInRange(Range.fromPointWithDelta(startPosition, 0, 1))
        endPosition = @findMatchingEndPair(startPosition, startPair, @matchManager.pairedCharacters[startPair])
      else if pair = @tagFinder.findEnclosingTags()
        {startRange, endRange} = pair
        if startRange.compare(endRange) > 0
          [startRange, endRange] = [endRange, startRange]
        startPosition = startRange.end
        endPosition = endRange.start.traverse(TWO_CHARS_BACKWARD_TRAVERSAL) # Don't select </

    if startPosition? and endPosition?
      rangeToSelect = new Range(startPosition.traverse(ONE_CHAR_FORWARD_TRAVERSAL), endPosition)
      @editor.setSelectedBufferRange(rangeToSelect)

  # Insert at the current cursor position a closing tag if there exists an
  # open tag that is not closed afterwards.
  closeTag: ->
    cursorPosition = @editor.getCursorBufferPosition()
    preFragment = @editor.getTextInBufferRange([Point.ZERO, cursorPosition])
    postFragment = @editor.getTextInBufferRange([cursorPosition, Point.INFINITY])

    if tag = @tagFinder.closingTagForFragments(preFragment, postFragment)
      @editor.insertText("</#{tag}>")

  isCursorOnCommentOrString: ->
    @isScopeCommentedOrString(@editor.getLastCursor().getScopeDescriptor().getScopesArray())

  isRangeCommentedOrString: (range) ->
    @isScopeCommentedOrString(@editor.scopeDescriptorForBufferPosition(range.start).getScopesArray())

  isScopeCommentedOrString: (scopesArray) ->
    for scope in scopesArray.reverse()
      scope = scope.split('.')
      return false if scope.includes('embedded') and scope.includes('source')
      return true if scope.includes('comment') or scope.includes('string')

    false
