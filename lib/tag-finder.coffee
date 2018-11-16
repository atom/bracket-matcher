{Range} = require 'atom'
_ = require 'underscore-plus'
SelfClosingTags = require './self-closing-tags'
TAG_SELECTOR_REGEX = /(\b|\.)(meta\.tag|punctuation\.definition\.tag)/
COMMENT_SELECTOR_REGEX = /(\b|\.)comment/

# Creates a regex to match opening tag with match[1] and closing tags with match[2]
#
# tagNameRegexStr - a regex string describing how to match the tagname.
#                   Should not contain capturing match groups.
#
# The resulting RegExp.
generateTagStartOrEndRegex = (tagNameRegexStr) ->
  notSelfClosingTagEnd = "(?:[^>\\/\"']|\"[^\"]*\"|'[^']*')*>"
  re = new RegExp("<(#{tagNameRegexStr})#{notSelfClosingTagEnd}|<\\/(#{tagNameRegexStr})>")

tagStartOrEndRegex = generateTagStartOrEndRegex("\\w[-\\w]*(?:\\:\\w[-\\w]*)?")

# Helper to find the matching start/end tag for the start/end tag under the
# cursor in XML, HTML, etc. editors.
module.exports =
class TagFinder
  constructor: (@editor) ->
    # 1. Tag prefix
    # 2. Closing tag (optional)
    # 3. Tag name
    # 4. Attributes (ids, classes, etc. - optional)
    # 5. Tag suffix
    # 6. Self-closing tag (optional)
    @tagPattern = /(<(\/)?)(.+?)(\s+.*?)?((\/)?>|$)/g
    @wordRegex = /.*?(>|$)/

  patternForTagName: (tagName) ->
    tagName = _.escapeRegExp(tagName)
    # 1. Start tag
    # 2. Tag name
    # 3. Attributes (optional)
    # 4. Tag suffix
    # 5. Self-closing tag (optional)
    # 6. End tag
    new RegExp("(<(#{tagName})(\\s+[^>]*?)?((/)?>))|(</#{tagName}[^>]*>)", 'gi')

  isRangeCommented: (range) ->
    @scopesForPositionMatchRegex(range.start, COMMENT_SELECTOR_REGEX)

  isTagRange: (range) ->
    @scopesForPositionMatchRegex(range.start, TAG_SELECTOR_REGEX)

  isCursorOnTag: ->
    @scopesForPositionMatchRegex(@editor.getCursorBufferPosition(), TAG_SELECTOR_REGEX)

  scopesForPositionMatchRegex: (position, regex) ->
    {tokenizedBuffer, buffer} = @editor
    {grammar} = tokenizedBuffer
    column = 0
    line = tokenizedBuffer.tokenizedLineForRow(position.row)
    return false unless line?
    lineLength = buffer.lineLengthForRow(position.row)
    scopeIds = line.openScopes.slice()
    for tag in line.tags by 1
      if tag >= 0
        nextColumn = column + tag
        break if nextColumn > position.column or nextColumn is lineLength
        column = nextColumn
      else if (tag & 1) is 1
        scopeIds.push(tag)
      else
        scopeIds.pop()

    scopeIds.some (scopeId) -> regex.test(grammar.scopeForId(scopeId))

  findStartTag: (tagName, endPosition, fullRange=false) ->
    scanRange = new Range([0, 0], endPosition)
    pattern = @patternForTagName(tagName)
    startRange = null
    unpairedCount = 0
    @editor.backwardsScanInBufferRange pattern, scanRange, ({match, range, stop}) =>
      return if @isRangeCommented(range)

      [entireMatch, isStartTag, tagName, attributes, suffix, isSelfClosingTag, isEndTag] = match

      return if isSelfClosingTag

      if isStartTag
        unpairedCount--
        if unpairedCount < 0
          stop()
          startRange = range
          unless fullRange
            # Move the start past the initial <
            startRange.start = startRange.start.translate([0, 1])

            # End right after the tag name
            startRange.end = startRange.start.translate([0, tagName.length])
      else
        unpairedCount++

    startRange

  findEndTag: (tagName, startPosition, fullRange=false) ->
    scanRange = new Range(startPosition, @editor.buffer.getEndPosition())
    pattern = @patternForTagName(tagName)
    endRange = null
    unpairedCount = 0
    @editor.scanInBufferRange pattern, scanRange, ({match, range, stop}) =>
      return if @isRangeCommented(range)

      [entireMatch, isStartTag, tagName, attributes, suffix, isSelfClosingTag, isEndTag] = match

      return if isSelfClosingTag

      if isStartTag
        unpairedCount++
      else
        unpairedCount--
        if unpairedCount < 0
          stop()
          endRange = range
          endRange = range.translate([0, 2], [0, -1]) unless fullRange # Subtract </ and > from range

    endRange

  findStartEndTags: (fullRange=false) ->
    ranges = null
    unpairedCount = 0
    endPosition = @editor.getCursorBufferPosition()
    {scopes} = @editor.scopeDescriptorForBufferPosition(endPosition)
    for scope in scopes
      if scope.startsWith('meta.tag')
        endPosition = @editor.getLastCursor().getCurrentWordBufferRange({wordRegex: /(.|\s)*?>/}).end
        break

    @editor.backwardsScanInBufferRange @tagPattern, [[0, 0], endPosition], ({match, range, stop}) =>
      return if @isRangeCommented(range)

      [entireMatch, prefix, isClosingTag, tagName, attributes, suffix, isSelfClosingTag] = match

      if isSelfClosingTag or SelfClosingTags.includes(tagName)
        if range.containsPoint(@editor.getCursorBufferPosition()) and not range.isEqual(@editor.getSelectedBufferRange())
          stop()
        else
          return
      else if isClosingTag
        if range.start.isEqual(@editor.getCursorBufferPosition()) or range.containsPoint(@editor.getCursorBufferPosition(), true)
          return

        unpairedCount++
        return
      else
        unpairedCount--
        if unpairedCount < 0
          stop()
        else
          return

      startRange = range
      unless fullRange
        if range.start.row is range.end.row
          # Move the start past the initial <
          startRange.start = startRange.start.translate([0, prefix.length])
          # End right after the tag name
          startRange.end = startRange.start.translate([0, tagName.length])
        else
          startRange = Range.fromObject([range.start.translate([0, prefix.length]), [range.start.row, Infinity]])

      if isSelfClosingTag or SelfClosingTags.includes(tagName)
        endRange = startRange
      else if isClosingTag
        endRange = @findStartTag(tagName, startRange.start, fullRange)
      else
        endRange = @findEndTag(tagName, startRange.end, fullRange)

      ranges = {startRange, endRange} if startRange? and endRange?
    ranges

  findCurrentTags: ->
    ranges = null
    endPosition = @editor.getLastCursor().getCurrentWordBufferRange({@wordRegex}).end
    @editor.backwardsScanInBufferRange @tagPattern, [[0, 0], endPosition], ({match, range, stop}) =>
      stop()

      [entireMatch, prefix, isClosingTag, tagName, attributes, suffix, isSelfClosingTag] = match

      startRange = range
      if range.start.row is range.end.row
        # Move the start past the initial <
        startRange.start = startRange.start.translate([0, prefix.length])
        # End right after the tag name
        startRange.end = startRange.start.translate([0, tagName.length])
      else
        startRange = Range.fromObject([range.start.translate([0, prefix.length]), [range.start.row, Infinity]])

      if isSelfClosingTag or SelfClosingTags.includes(tagName)
        endRange = startRange
      else if isClosingTag
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
    @findCurrentTags() if @isCursorOnTag()

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
  # Returns an array of strings. Each string is a tag that is still to be closed
  # (the most recent non closed tag is at the end of the array).
  tagsNotClosedInFragment: (fragment) ->
    @parseFragment fragment, [], tagStartOrEndRegex, -> true

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
    stack = @parseFragment fragment, stack, generateTagStartOrEndRegex(escapedTag), (s) ->
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
