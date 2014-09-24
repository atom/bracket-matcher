_ = require 'underscore-plus'
{Range, View} = require 'atom'
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
class BracketMatcherView extends View
  @content: ->
    @div =>
      @div class: 'bracket-matcher', style: 'display: none', outlet: 'startView'
      @div class: 'bracket-matcher', style: 'display: none', outlet: 'endView'

  initialize: (@editorView) ->
    @editor = @editorView.getModel()
    @tagFinder = new TagFinder(@editor)
    @pairHighlighted = false
    @tagHighlighted = false
    @updateHighlights = false

    @subscribe atom.config.observe 'editor.fontSize', =>
      @updateMatch()

    @subscribe @editor.getBuffer(), 'changed', =>
      @updateHighlights = true

    @subscribe @editor, 'screen-lines-changed', =>
      @updateHighlights = true

    @subscribe @editorView, 'editor:display-updated', =>
      if @updateHighlights
        @updateHighlights = false
        @updateMatch()

    @subscribe @editor, 'soft-wrap-changed', =>
      @updateHighlights = true

    @subscribe @editor, 'grammar-changed', =>
      @updateHighlights = true

    @subscribeToCursor()

    @subscribeToCommand @editorView, 'bracket-matcher:go-to-matching-bracket', =>
      @goToMatchingPair()

    @subscribeToCommand @editorView, 'bracket-matcher:go-to-enclosing-bracket', =>
      @goToEnclosingPair()

    @subscribeToCommand @editorView, 'bracket-matcher:select-inside-brackets', =>
      @selectInsidePair()

    @subscribeToCommand @editorView, 'bracket-matcher:close-tag', =>
      @closeTag()

    @subscribeToCommand @editorView, 'bracket-matcher:remove-matching-brackets', =>
      @removeMatchingBrackets()

    @editorView.underlayer.append(this)
    @updateMatch()

  subscribeToCursor: ->
    cursor = @editor.getLastCursor()
    return unless cursor?

    @subscribe cursor, 'moved', =>
      @updateMatch()

    @subscribe cursor, 'destroyed', =>
      @unsubscribe(cursor)
      @subscribeToCursor()
      @updateMatch() if @editor.isAlive()

  updateMatch: ->
    if @pairHighlighted
      @startView.element.style.display = 'none'
      @endView.element.style.display = 'none'
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
      @moveStartView([position, position.add([0, 1])])
      @moveEndView([matchPosition, matchPosition.add([0, 1])])
      @pairHighlighted = true
    else
      if pair = @tagFinder.findMatchingTags()
        @moveStartView(pair.startRange)
        @moveEndView(pair.endRange)
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
            position = position.add([0, -1])
          @editor.setCursorBufferPosition(position)
          @editor.delete()
        else
          @editor.backspace()
      else
        @editor.backspace()

  findMatchingEndPair: (startPairPosition, startPair, endPair) ->
    scanRange = new Range(startPairPosition.add([0, 1]), @editor.buffer.getEndPosition())
    endPairPosition = null
    unpairedCount = 0
    @editor.scanInBufferRange pairRegexes[startPair], scanRange, ({match, range, stop}) ->
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
    scanRange = new Range([0, 0], endPairPosition)
    startPairPosition = null
    unpairedCount = 0
    @editor.backwardsScanInBufferRange pairRegexes[startPair], scanRange, ({match, range, stop}) ->
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
    scanRange = new Range([0, 0], cursorPosition)
    startPair = _.escapeRegExp(_.keys(startPairMatches).join(''))
    endPair = _.escapeRegExp(_.keys(endPairMatches).join(''))
    combinedRegExp = new RegExp("[#{startPair}#{endPair}]", 'g')
    startPairRegExp = new RegExp("[#{startPair}]", 'g')
    endPairRegExp = new RegExp("[#{endPair}]", 'g')
    startPosition = null
    unpairedCount = 0
    @editor.backwardsScanInBufferRange combinedRegExp, scanRange, ({match, range, stop}) =>
      if match[0].match(endPairRegExp)
        unpairedCount++
      else if match[0].match(startPairRegExp)
        unpairedCount--
        startPosition = range.start
        stop() if unpairedCount < 0
     startPosition

  moveHighlightView: (view, bufferRange) ->
    bufferRange = Range.fromObject(bufferRange)
    view.bufferPosition = bufferRange.start
    view.bufferRange = bufferRange

    startPixelPosition = @editor.pixelPositionForBufferPosition(bufferRange.start)
    endPixelPosition = @editor.pixelPositionForBufferPosition(bufferRange.end)

    view.element.style.display = ''
    view.element.style.top = "#{startPixelPosition.top}px"
    view.element.style.left = "#{startPixelPosition.left}px"
    view.element.style.width = "#{endPixelPosition.left - startPixelPosition.left}px"
    view.element.style.height = "#{@editorView.lineHeight}px"

  moveStartView: (bufferRange) ->
    @moveHighlightView(@startView, bufferRange)

  moveEndView: (bufferRange) ->
    @moveHighlightView(@endView, bufferRange)

  findCurrentPair: (matches) ->
    position = @editor.getCursorBufferPosition()
    currentPair = @editor.getTextInRange(Range.fromPointWithDelta(position, 0, 1))
    unless matches[currentPair]
      position = position.add([0, -1])
      currentPair = @editor.getTextInRange(Range.fromPointWithDelta(position, 0, 1))
    if matchingPair = matches[currentPair]
      {position, currentPair, matchingPair}
    else
      {}

  goToMatchingPair: ->
    return @goToEnclosingPair() unless @pairHighlighted
    return unless @editorView.underlayer.isVisible()

    position = @editor.getCursorBufferPosition()

    if @tagHighlighted
      startRange = @startView.bufferRange
      tagLength = startRange.end.column - startRange.start.column
      endRange = @endView.bufferRange
      if startRange.compare(endRange) > 0
        [startRange, endRange] = [endRange, startRange]

      # include the <
      startRange = new Range(startRange.start.add([0, -1]), endRange.end.add([0, -1]))
      # include the </
      endRange = new Range(endRange.start.add([0, -2]), endRange.end.add([0, -2]))

      if position.isLessThan(endRange.start)
        tagCharacterOffset = position.column - startRange.start.column
        tagCharacterOffset++ if tagCharacterOffset > 0
        tagCharacterOffset = Math.min(tagCharacterOffset, tagLength + 2) # include </
        @editor.setCursorBufferPosition(endRange.start.add([0, tagCharacterOffset]))
      else
        tagCharacterOffset = position.column - endRange.start.column
        tagCharacterOffset-- if tagCharacterOffset > 1
        tagCharacterOffset = Math.min(tagCharacterOffset, tagLength + 1) # include <
        @editor.setCursorBufferPosition(startRange.start.add([0, tagCharacterOffset]))
    else
      previousPosition = position.add([0, -1])
      startPosition = @startView.bufferPosition
      endPosition = @endView.bufferPosition

      if position.isEqual(startPosition)
        @editor.setCursorBufferPosition(endPosition.add([0, 1]))
      else if previousPosition.isEqual(startPosition)
        @editor.setCursorBufferPosition(endPosition)
      else if position.isEqual(endPosition)
        @editor.setCursorBufferPosition(startPosition.add([0, 1]))
      else if previousPosition.isEqual(endPosition)
        @editor.setCursorBufferPosition(startPosition)

  goToEnclosingPair: ->
    return if @pairHighlighted
    return unless @editorView.underlayer.isVisible()

    if matchPosition = @findAnyStartPair(@editor.getCursorBufferPosition())
      @editor.setCursorBufferPosition(matchPosition)
    else if pair = @tagFinder.findEnclosingTags()
      {startRange, endRange} = pair
      if startRange.compare(endRange) > 0
        [startRange, endRange] = [endRange, startRange]
      @editor.setCursorBufferPosition(pair.startRange.start)

  selectInsidePair: ->
    return unless @editorView.underlayer.isVisible()

    if @pairHighlighted
      startRange = @startView.bufferRange
      endRange = @endView.bufferRange

      if startRange.compare(endRange) > 0
        [startRange, endRange] = [endRange, startRange]

      if @tagHighlighted
        startPosition = startRange.end
        endPosition = endRange.start.add([0, -2]) # Don't select </
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
        endPosition = endRange.start.add([0, -2]) # Don't select </

    if startPosition? and endPosition?
      rangeToSelect = new Range(startPosition.add([0, 1]), endPosition)
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
