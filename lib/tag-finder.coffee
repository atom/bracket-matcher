{Range} = require 'atom'
{ScopeSelector} = require 'first-mate'

# Helper to find the matching start/end tag for the start/end tag under the
# cursor in XML, HTML, etc. editors.
module.exports =
class TagFinder
  constructor: (@editorView) ->
    {@editor} = @editorView

    @tagSelector = new ScopeSelector('entity.name.tag')
    @commentSelector = new ScopeSelector('comment.*')

  getTagName: ->
    wordRange = @editor.getCursor().getCurrentWordBufferRange()
    tagName = @editor.getTextInRange(wordRange)
    tagName.replace(/[<>/]/g, '').trim()

  getTagPattern: ->
    tagName = @getTagName()
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

  findStartTag: ->
    scanRange = new Range([0, 0], @editor.getCursorBufferPosition())
    startRange = null
    unpairedCount = 0
    @editor.backwardsScanInBufferRange @getTagPattern(), scanRange, ({match, range, stop}) =>
      return if @isRangeCommented(range)
      if match[1]
        unpairedCount--
        if unpairedCount < 0
          startRange = range.translate([0, 1], [0, -match[2].length])
          stop()
      else
        unpairedCount++

    if startRange?
      {startRange, endRange: @getTagStartRange()}

  findEndTag: ->
    scanRange = new Range(@editor.getCursorBufferPosition(), @editor.buffer.getEndPosition())
    endRange = null
    unpairedCount = 0
    @editor.scanInBufferRange @getTagPattern(), scanRange, ({match, range, stop}) =>
      return if @isRangeCommented(range)
      if match[1]
        unpairedCount++
      else
        unpairedCount--
        if unpairedCount < 0
          endRange = range.translate([0, 2], [0, -1])
          stop()

    if endRange?
      {startRange: @getTagStartRange(), endRange}

  findPair: ->
    return unless isCursorOnTag()

    ranges = null
    @editor.backwardsScanInBufferRange /<\/?/, [[0, 0], @editor.getCursorBufferPosition()], ({match, range, stop}) =>
      stop()
      if match[0].length is 2
        ranges = @findStartTag()
      else
        ranges = @findEndTag()
    ranges
