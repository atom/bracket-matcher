{Range} = require 'atom'
{ScopeSelector} = require 'first-mate'

# Helper to find the matching start/end tag for the start/end tag under the
# cursor in XML, HTML, etc. editors.
module.exports =
class TagFinder
  constructor: (@editorView) ->
    {@editor} = @editorView

    @tagSelector = new ScopeSelector('meta.tag')
    @commentSelector = new ScopeSelector('comment.*')

  getTagPattern: (tagName) ->
    new RegExp("(<#{tagName}([\\s>]|$))|(</#{tagName}>)", 'gi')

  isRangeCommented: (range) ->
    scopes = @editor.scopesForBufferPosition(range.start)
    @commentSelector.matches(scopes)

  isCursorOnTag: ->
    @tagSelector.matches(@editor.getCursorScopes())

  getTagStartRange: ->
    tagStartPosition = null
    tagEndPosition = null

    position = @editor.getCursorBufferPosition()
    @editor.backwardsScanInBufferRange /<\/?/, [[0, 0], position], ({match, range, stop}) ->
      tagStartPosition = range.translate([0, match[0].length]).start
      stop()
    @editor.scanInBufferRange /[\s>]|$/, [position, @editor.buffer.getEndPosition()], ({match, range, stop}) ->
      tagEndPosition = range.translate([0, -1]).end
      if range.start.row isnt range.end.row
        tagEndPosition = [range.start.row, Infinity]
      stop()

    [tagStartPosition, tagEndPosition]

  findStartTag: (tagName, endPosition) ->
    scanRange = new Range([0, 0], endPosition)
    startRange = null
    unpairedCount = 0
    @editor.backwardsScanInBufferRange @getTagPattern(tagName), scanRange, ({match, range, stop}) =>
      return if @isRangeCommented(range)

      if match[1]
        unpairedCount--
        if unpairedCount < 0
          startRange = range.translate([0, 1], [0, -match[2].length]) # Subtract < and tag name suffix from range
          stop()
      else
        unpairedCount++

    startRange

  findEndTag: (tagName, startPosition) ->
    scanRange = new Range(startPosition, @editor.buffer.getEndPosition())
    endRange = null
    unpairedCount = 0
    @editor.scanInBufferRange @getTagPattern(tagName), scanRange, ({match, range, stop}) =>
      return if @isRangeCommented(range)
      if match[1]
        unpairedCount++
      else
        unpairedCount--
        if unpairedCount < 0
          endRange = range.translate([0, 2], [0, -1]) # Subtract </ and > from range
          stop()

    endRange

  findPair: ->
    return unless @isCursorOnTag()

    ranges = null
    endPosition = [@editor.getCursor().getBufferRow(), Infinity]
    @editor.backwardsScanInBufferRange /(<(\/?))([^\s>]+)([\s>]|$)/, [[0, 0], endPosition], ({match, range, stop}) =>
      stop()

      [entireMatch, prefix, isClosingTag, tagName, suffix] = match

      if range.start.row is range.end.row
        startRange = range.translate([0, prefix.length], [0, -suffix.length])
      else
        startRange = [range.start, [range.end.row, Infinity]]

      return if @editor.getCursorBufferPosition().isLessThan(startRange.start)

      if isClosingTag
        endRange = @findStartTag(tagName, startRange.start)
      else
        endRange = @findEndTag(tagName, startRange.end)

      ranges = {startRange, endRange} if startRange? and endRange?
    ranges
