_ = require 'underscore-plus'
{Range, View} = require 'atom'

startPairMatches =
  '(': ')'
  '[': ']'
  '{': '}'

endPairMatches =
  ')': '('
  ']': '['
  '}': '{'

module.exports =
class BracketMatcherView extends View
  @content: ->
    @div =>
      @div class: 'bracket-matcher', style: 'display: none', outlet: 'startView'
      @div class: 'bracket-matcher', style: 'display: none', outlet: 'endView'

  initialize: (@editorView) ->
    {@editor} = @editorView
    @pairHighlighted = false

    @subscribe atom.config.observe 'editor.fontSize', =>
      @updateMatch()

    @subscribe @editor.getCursor(), 'moved', =>
      @updateMatch()

    @subscribeToCommand @editorView, 'bracket-matcher:go-to-matching-bracket', =>
      @goToMatchingPair()

    @subscribeToCommand @editorView, 'bracket-matcher:go-to-enclosing-bracket', =>
      @goToEnclosingPair()

    @editorView.underlayer.append(this)
    @updateMatch()

  updateMatch: ->
    if @pairHighlighted
      @startView.hide()
      @endView.hide()
    @pairHighlighted = false

    return unless @editor.getSelection().isEmpty()
    return if @editor.isFoldedAtCursorRow()

    {position, currentPair, matchingPair} = @findCurrentPair(startPairMatches)
    if position
      matchPosition = @findMatchingEndPair(position, currentPair, matchingPair)
    else
      {position, currentPair, matchingPair} = @findCurrentPair(endPairMatches)
      if position
        matchPosition = @findMatchingStartPair(position, matchingPair, currentPair)

    if position? and matchPosition?
      @moveHighlightViews([position, matchPosition])
      @pairHighlighted = true

  findMatchingEndPair: (startPairPosition, startPair, endPair) ->
    scanRange = new Range(startPairPosition.translate([0, 1]), @editor.buffer.getEndPosition())
    regex = new RegExp("[#{_.escapeRegExp(startPair + endPair)}]", 'g')
    endPairPosition = null
    unpairedCount = 0
    @editor.scanInBufferRange regex, scanRange, ({match, range, stop}) =>
      if match[0] is startPair
        unpairedCount++
      else if match[0] is endPair
        unpairedCount--
        endPairPosition = range.start
        stop() if unpairedCount < 0
    endPairPosition

  findMatchingStartPair: (endPairPosition, startPair, endPair) ->
    scanRange = new Range([0, 0], endPairPosition)
    regex = new RegExp("[#{_.escapeRegExp(startPair + endPair)}]", 'g')
    startPairPosition = null
    unpairedCount = 0
    @editor.backwardsScanInBufferRange regex, scanRange, ({match, range, stop}) =>
      if match[0] is endPair
        unpairedCount++
      else if match[0] is startPair
        unpairedCount--
        startPairPosition = range.start
        stop() if unpairedCount < 0
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

  moveHighlightView: (view, bufferPosition, pixelPosition) ->
    view.bufferPosition = bufferPosition
    [element] = view
    element.style.display = 'block'
    element.style.top = "#{pixelPosition.top}px"
    element.style.left = "#{pixelPosition.left}px"
    element.style.width = "#{@editorView.charWidth}px"
    element.style.height = "#{@editorView.lineHeight}px"

  moveHighlightViews: (bufferRange) ->
    {start, end} = Range.fromObject(bufferRange)
    startPixelPosition = @editorView.pixelPositionForBufferPosition(start)
    endPixelPosition = @editorView.pixelPositionForBufferPosition(end)
    @moveHighlightView(@startView, start, startPixelPosition)
    @moveHighlightView(@endView, end, endPixelPosition)

  findCurrentPair: (matches) ->
    position = @editor.getCursorBufferPosition()
    currentPair = @editor.getTextInRange(Range.fromPointWithDelta(position, 0, 1))
    unless matches[currentPair]
      position = position.translate([0, -1])
      currentPair = @editor.getTextInRange(Range.fromPointWithDelta(position, 0, 1))
    if matchingPair = matches[currentPair]
      {position, currentPair, matchingPair}
    else
      {}

  goToMatchingPair: ->
    return @goToEnclosingPair() unless @pairHighlighted
    return unless @editorView.underlayer.isVisible()

    position = @editor.getCursorBufferPosition()
    previousPosition = position.translate([0, -1])
    startPosition = @startView.bufferPosition
    endPosition = @endView.bufferPosition

    if position.isEqual(startPosition)
      @editor.setCursorBufferPosition(endPosition.translate([0, 1]))
    else if previousPosition.isEqual(startPosition)
      @editor.setCursorBufferPosition(endPosition)
    else if position.isEqual(endPosition)
      @editor.setCursorBufferPosition(startPosition.translate([0, 1]))
    else if previousPosition.isEqual(endPosition)
      @editor.setCursorBufferPosition(startPosition)

  goToEnclosingPair: ->
    return if @pairHighlighted
    return unless @editorView.underlayer.isVisible()
    position = @editor.getCursorBufferPosition()
    matchPosition = @findAnyStartPair(position)
    if matchPosition
      @editor.setCursorBufferPosition(matchPosition)
