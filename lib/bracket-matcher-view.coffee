{CompositeDisposable} = require 'atom'
_ = require 'underscore-plus'
{Range} = require 'atom'
TagFinder = require './tag-finder'

startPairMatches =
  '(': ')'
  '[': ']'
  '{': '}'

endPairMatches =
  ')': '('
  ']': '['
  '}': '{'

pairRegexes = {}
for startPair, endPair of startPairMatches
  pairRegexes[startPair] = new RegExp("[#{_.escapeRegExp(startPair + endPair)}]", 'g')

module.exports =
class BracketMatcherView
  constructor: (@editor, editorElement) ->
    @subscriptions = new CompositeDisposable
    @tagFinder = new TagFinder(@editor)
    @pairHighlighted = false
    @tagHighlighted = false

    @subscriptions.add @editor.onDidChange =>
      @updateMatch()

    @subscriptions.add @editor.onDidChangeGrammar =>
      @updateMatch()

    @subscribeToCursor()

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

    @updateMatch()

  subscribeToCursor: ->
    cursor = @editor.getLastCursor()
    return unless cursor?

    cursorSubscriptions = new CompositeDisposable
    cursorSubscriptions.add cursor.onDidChangePosition =>
      @updateMatch()

    cursorSubscriptions.add cursor.onDidDestroy =>
      cursorSubscriptions.dispose()
      @subscribeToCursor()
      @updateMatch() if @editor.isAlive()

  updateMatch: ->
    if @pairHighlighted
      @editor.destroyMarker(@startMarker.id)
      @editor.destroyMarker(@endMarker.id)

    @pairHighlighted = false
    @tagHighlighted = false

    return unless @editor.getLastSelection().isEmpty()
    return if @editor.isFoldedAtCursorRow()

    {position, currentPair, matchingPair} = @findCurrentPair(startPairMatches)
    if position
      matchPosition = @findMatchingEndPair(position, currentPair, matchingPair)
    else
      {position, currentPair, matchingPair} = @findCurrentPair(endPairMatches)
      if position
        matchPosition = @findMatchingStartPair(position, matchingPair, currentPair)

    if position? and matchPosition?
      @startMarker = @createMarker([position, position.traverse([0, 1])])
      @endMarker = @createMarker([matchPosition, matchPosition.traverse([0, 1])])
      @pairHighlighted = true
    else
      if pair = @tagFinder.findMatchingTags()
        @startMarker = @createMarker(pair.startRange)
        @endMarker = @createMarker(pair.endRange)
        @pairHighlighted = true
        @tagHighlighted = true

  removeMatchingBrackets: ->
    return @editor.backspace() if @editor.hasMultipleCursors()

    @editor.transact =>
      @editor.selectLeft() if @editor.getLastSelection().isEmpty()
      text = @editor.getSelectedText()

      #check if the character to the left is part of a pair
      if startPairMatches.hasOwnProperty(text) or endPairMatches.hasOwnProperty(text)
        {position, currentPair, matchingPair} = @findCurrentPair(startPairMatches)
        if position
          matchPosition = @findMatchingEndPair(position, currentPair, matchingPair)
        else
          {position, currentPair, matchingPair} = @findCurrentPair(endPairMatches)
          if position
            matchPosition = @findMatchingStartPair(position, matchingPair, currentPair)

        if position? and matchPosition?
          @editor.setCursorBufferPosition(matchPosition)
          @editor.delete()
          # if on the same line and the cursor is in front of an end pair
          # offset by one to make up for the missing character
          if position.row is matchPosition.row and endPairMatches.hasOwnProperty(currentPair)
            position = position.traverse([0, -1])
          @editor.setCursorBufferPosition(position)
          @editor.delete()
        else
          @editor.backspace()
      else
        @editor.backspace()

  positionIsInComment: (position) ->
    !!@editor.scopeDescriptorForBufferPosition(position).
              getScopeChain().match(/\B\.comment([^\w]|$)/)

  findMatchingEndPair: (startPairPosition, startPair, endPair) ->
    inComment = @positionIsInComment(startPairPosition)
    scanRange = new Range(startPairPosition.traverse([0, 1]), @editor.buffer.getEndPosition())
    endPairPosition = null
    unpairedCount = 0
    @editor.scanInBufferRange pairRegexes[startPair], scanRange, ({match, range, stop}) =>
      return unless inComment == @positionIsInComment(range.start)

      switch match[0]
        when startPair
          unpairedCount++
        when endPair
          unpairedCount--
          if unpairedCount < 0
            endPairPosition = range.start
            stop()

    endPairPosition

  findMatchingStartPair: (endPairPosition, startPair, endPair) ->
    inComment = @positionIsInComment(endPairPosition)
    scanRange = new Range([0, 0], endPairPosition)
    startPairPosition = null
    unpairedCount = 0
    @editor.backwardsScanInBufferRange pairRegexes[startPair], scanRange, ({match, range, stop}) =>
      return unless inComment == @positionIsInComment(range.start)

      switch match[0]
        when startPair
          unpairedCount--
          if unpairedCount < 0
            startPairPosition = range.start
            stop()
        when endPair
          unpairedCount++
    startPairPosition

  findAnyStartPair: (cursorPosition) ->
    inComment = @positionIsInComment(cursorPosition)
    scanRange = new Range([0, 0], cursorPosition)
    startPair = _.escapeRegExp(_.keys(startPairMatches).join(''))
    endPair = _.escapeRegExp(_.keys(endPairMatches).join(''))
    combinedRegExp = new RegExp("[#{startPair}#{endPair}]", 'g')
    startPairRegExp = new RegExp("[#{startPair}]", 'g')
    endPairRegExp = new RegExp("[#{endPair}]", 'g')
    startPosition = null
    unpairedCount = 0
    @editor.backwardsScanInBufferRange combinedRegExp, scanRange, ({match, range, stop}) =>
      return unless inComment == @positionIsInComment(range.start)

      if match[0].match(endPairRegExp)
        unpairedCount++
      else if match[0].match(startPairRegExp)
        unpairedCount--
        startPosition = range.start
        stop() if unpairedCount < 0
    startPosition

  createMarker: (bufferRange) ->
    marker = @editor.markBufferRange(bufferRange)
    @editor.decorateMarker(marker, type: 'highlight', class: 'bracket-matcher', deprecatedRegionClass: 'bracket-matcher')
    marker

  findCurrentPair: (matches) ->
    position = @editor.getCursorBufferPosition()
    currentPair = @editor.getTextInRange(Range.fromPointWithDelta(position, 0, 1))
    unless matches[currentPair]
      position = position.traverse([0, -1])
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
      startRange = new Range(startRange.start.traverse([0, -1]), endRange.end.traverse([0, -1]))
      # include the </
      endRange = new Range(endRange.start.traverse([0, -2]), endRange.end.traverse([0, -2]))

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
      previousPosition = position.traverse([0, -1])
      startPosition = @startMarker.getStartBufferPosition()
      endPosition = @endMarker.getStartBufferPosition()

      if position.isEqual(startPosition)
        @editor.setCursorBufferPosition(endPosition.traverse([0, 1]))
      else if previousPosition.isEqual(startPosition)
        @editor.setCursorBufferPosition(endPosition)
      else if position.isEqual(endPosition)
        @editor.setCursorBufferPosition(startPosition.traverse([0, 1]))
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
        endPosition = endRange.start.traverse([0, -2]) # Don't select </
      else
        startPosition = startRange.start
        endPosition = endRange.start
    else
      if startPosition = @findAnyStartPair(@editor.getCursorBufferPosition())
        startPair = @editor.getTextInRange(Range.fromPointWithDelta(startPosition, 0, 1))
        endPosition = @findMatchingEndPair(startPosition, startPair, startPairMatches[startPair])
      else if pair = @tagFinder.findEnclosingTags()
        {startRange, endRange} = pair
        if startRange.compare(endRange) > 0
          [startRange, endRange] = [endRange, startRange]
        startPosition = startRange.end
        endPosition = endRange.start.traverse([0, -2]) # Don't select </

    if startPosition? and endPosition?
      rangeToSelect = new Range(startPosition.traverse([0, 1]), endPosition)
      @editor.setSelectedBufferRange(rangeToSelect)

  # Insert at the current cursor position a closing tag if there exists an
  # open tag that is not closed afterwards.
  closeTag: ->
    cursorPosition = @editor.getCursorBufferPosition()
    textLimits = @editor.getBuffer().getRange()
    preFragment = @editor.getTextInBufferRange([[0, 0], cursorPosition])
    postFragment = @editor.getTextInBufferRange([cursorPosition, [Infinity, Infinity]])

    if tag = @tagFinder.closingTagForFragments(preFragment, postFragment)
      @editor.insertText("</#{tag}>")
