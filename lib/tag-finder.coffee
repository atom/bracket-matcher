{Range} = require 'atom'
_ = require 'underscore-plus'
SelectorCache = require './selector-cache'
SelfClosingTags = require './self-closing-tags'

# Helper to find the matching start/end tag for the start/end tag under the
# cursor in XML, HTML, etc. editors.
module.exports =
class TagFinder
  constructor: (@editor) ->
    @tagPattern = /(<(\/?))([^\s>]+)([\s>]|$)/
    @wordRegex = /[^>\r\n]*/
    @tagSelector = SelectorCache.get('meta.tag | punctuation.definition.tag')
    @commentSelector = SelectorCache.get('comment.*')

  patternForTagName: (tagName) ->
    tagName = _.escapeRegExp(tagName)
    new RegExp("(<#{tagName}([\\s>]|$))|(</#{tagName}>)", 'gi')

  isRangeCommented: (range) ->
    scopes = @editor.scopeDescriptorForBufferPosition(range.start).getScopesArray()
    @commentSelector.matches(scopes)

  isTagRange: (range) ->
    scopes = @editor.scopeDescriptorForBufferPosition(range.start).getScopesArray()
    @tagSelector.matches(scopes)

  isCursorOnTag: ->
    @tagSelector.matches(@editor.getLastCursor().getScopeDescriptor().getScopesArray())

  findStartTag: (tagName, endPosition) ->
    scanRange = new Range([0, 0], endPosition)
    pattern = @patternForTagName(tagName)
    startRange = null
    unpairedCount = 0
    @editor.backwardsScanInBufferRange pattern, scanRange, ({match, range, stop}) =>
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
    pattern = @patternForTagName(tagName)
    endRange = null
    unpairedCount = 0
    @editor.scanInBufferRange pattern, scanRange, ({match, range, stop}) =>
      return if @isRangeCommented(range)

      if match[1]
        unpairedCount++
      else
        unpairedCount--
        if unpairedCount < 0
          endRange = range.translate([0, 2], [0, -1]) # Subtract </ and > from range
          stop()

    endRange

  findStartEndTags: ->
    ranges = null
    endPosition = @editor.getLastCursor().getCurrentWordBufferRange({@wordRegex}).end
    @editor.backwardsScanInBufferRange @tagPattern, [[0, 0], endPosition], ({match, range, stop}) =>
      stop()

      [entireMatch, prefix, isClosingTag, tagName, suffix] = match

      if range.start.row is range.end.row
        startRange = range.translate([0, prefix.length], [0, -suffix.length])
      else
        startRange = Range.fromObject([range.start.translate([0, prefix.length]), [range.start.row, Infinity]])

      if isClosingTag
        endRange = @findStartTag(tagName, startRange.start)
      else
        endRange = @findEndTag(tagName, startRange.end)

      ranges = {startRange, endRange} if startRange? and endRange?
    ranges

  findEnclosingTags: ->
    if ranges = @findStartEndTags()
      if @isTagRange(ranges.startRange) and @isTagRange(ranges.endRange)
        return ranges

    null

  findMatchingTags: ->
    @findStartEndTags() if @isCursorOnTag()

  # Parses a fragment of html returning the stack (i.e., an array) of open tags
  #
  # fragment  - the fragment of html to be analysed
  # stack     - an array to be populated (can be non-empty)
  # matchExpr - a RegExp describing how to match opening/closing tags
  #             the opening/closing descriptions must be captured subexpressions
  #             so that the code can refer to match[1] to check if an opening
  #             tag has been found, and to match[2] to check if a closing tag
  #             has been found
  # cond      - a condition to be checked at each iteration. If the function
  #             returns false the processing is immediately interrupted. When
  #             called the current stack is provided to the function.
  #
  # Returns an array of strings. Each string is a tag that is still to be closed
  # (the most recent non closed tag is at the end of the array).
  parseFragment: (fragment, stack, matchExpr, cond) ->
    match = fragment.match(matchExpr)
    while match and cond(stack)
      if SelfClosingTags.indexOf(match[1]) is -1
        topElem = stack[stack.length-1]

        if match[2] and topElem is match[2]
          stack.pop()
        else if match[1]
          stack.push match[1]

      fragment = fragment.substr(match.index + match[0].length)
      match = fragment.match(matchExpr)

    stack

  # Parses the given fragment of html code returning the last unclosed tag.
  #
  # fragment - a string containing a fragment of html code.
  #
  # Returns a string with the name of the most recent unclosed tag.
  tagsNotClosedInFragment: (fragment) ->
    @parseFragment fragment, [], /<(\w[-\w]*(?:\:\w[-\w]*)?)|<\/(\w[-\w]*(?:\:\w[-\w]*)?)/, -> true

  # Parses the given fragment of html code and returns true if the given tag
  # has a matching closing tag in it. If tag is reopened and reclosed in the
  # given fragment then the end point of that pair does not count as a matching
  # closing tag.
  tagDoesNotCloseInFragment: (tags, fragment) ->
    return false if tags.length is 0

    stack = tags
    stackLength = stack.length
    tag = tags[tags.length-1]
    escapedTag = _.escapeRegExp(tag)
    matchExpr = new RegExp("<(#{escapedTag})|<\/(#{escapedTag})")
    stack = @parseFragment fragment, stack, matchExpr, (s) ->
      s.length >= stackLength or s[s.length-1] is tag

    stack.length > 0 and stack[stack.length-1] is tag

  # Parses preFragment and postFragment returning the last open tag in
  # preFragment that is not closed in postFragment.
  #
  # Returns a tag name or null if it can't find it.
  closingTagForFragments: (preFragment, postFragment) ->
    tags = @tagsNotClosedInFragment(preFragment)
    tag = tags[tags.length-1]
    if @tagDoesNotCloseInFragment(tags, postFragment)
      tag
    else
      null
