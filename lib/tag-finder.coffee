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

  isRangeCommented: (range) ->
    scopes = @editor.scopesForBufferPosition(range.start)
    @commentSelector.matches(scopes)

  getTagStartPosition: ->
    position = @editor.getCursorBufferPosition()
    tagStartPosition = null
    @editor.backwardsScanInBufferRange /<\/?/, [[0, 0], position], ({match, range, stop}) ->
      tagStartPosition = range.translate([0, match[0].length]).start
      stop()
    tagStartPosition

  findStartingTag: ->
    scanRange = new Range([0, 0], @editor.getCursorBufferPosition())
    startingTagRange = null
    unpairedCount = 0
    @editor.backwardsScanInBufferRange @getTagPattern(), scanRange, ({match, range, stop}) =>
      return if @isRangeCommented(range)
      if match[1]
        unpairedCount--
        if unpairedCount < 0
          startingTagRange = range.translate([0, 1])
          stop()
      else if match[2]
        unpairedCount++

    if startingTagRange?
      {startPosition: startingTagRange.start, endPosition: @getTagStartPosition()}

  getTagPattern: ->
    tagName = @getTagName()
    new RegExp("(<#{tagName}[\s>])|(</#{tagName}>)", 'gi')

  findClosingTag: ->
    scanRange = new Range(@editor.getCursorBufferPosition(), @editor.buffer.getEndPosition())
    closingTagRange = null
    unpairedCount = 0
    @editor.scanInBufferRange @getTagPattern(), scanRange, ({match, range, stop}) =>
      return if @isRangeCommented(range)
      if match[2]
        unpairedCount--
        if unpairedCount < 0
          closingTagRange = range.translate([0, 2])
          stop()
      else if match[1]
        unpairedCount++

    if closingTagRange?
      {startPosition: @getTagStartPosition(), endPosition: closingTagRange.start}

  findPair: ->
    return unless @tagSelector.matches(@editor.getCursorScopes())

    positions = null
    @editor.backwardsScanInBufferRange /<\/?/, [[0, 0], @editor.getCursorBufferPosition()], ({match, range, stop}) =>
      stop()
      if match[0].length is 2
        positions = @findStartingTag()
      else
        positions = @findClosingTag()
    positions
