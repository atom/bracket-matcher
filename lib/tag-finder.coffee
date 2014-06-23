{Range} = require 'atom'
_ = require 'underscore-plus'
{ScopeSelector} = require 'first-mate'

SELF_CLOSING_TAGS = [
  "area","base","br","col","command","embed","hr","img",
  "input","keygen","link","meta","param","source","track","wbr"
  ]


# Helper to find the matching start/end tag for the start/end tag under the
# cursor in XML, HTML, etc. editors.
module.exports =
class TagFinder
  constructor: (@editor) ->
    @tagPattern = /(<(\/?))([^\s>]+)([\s>]|$)/
    @wordRegex = /[^>\r\n]*/
    @tagSelector = new ScopeSelector('meta.tag | punctuation.definition.tag')
    @commentSelector = new ScopeSelector('comment.*')

  patternForTagName: (tagName) ->
    tagName = _.escapeRegExp(tagName)
    new RegExp("(<#{tagName}([\\s>]|$))|(</#{tagName}>)", 'gi')

  isRangeCommented: (range) ->
    scopes = @editor.scopesForBufferPosition(range.start)
    @commentSelector.matches(scopes)

  isCursorOnTag: ->
    @tagSelector.matches(@editor.getCursorScopes())

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

  findMatchingTags: ->
    return unless @isCursorOnTag()

    ranges = null
    endPosition = @editor.getCursor().getCurrentWordBufferRange({@wordRegex}).end
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

  # Parses a fragment of html returning the stack (i.e., an array) of open tags
  #
  # fragment  - the fragment of html to be analysed
  # stack     - an array to be populated (can be non-empty)
  # matchExpr - a RegExp describing how to match opening/closing tags
  #    the opening/closing descriptions must be captured subexpressions
  #    so that the code can refer to match[1] to check if an opening tag
  #    has been found, and to match[2] to check if a closing tag has been
  #    found
  # cond      - a condition to be checked at each iteration. If the function
  #    returns false the processing is immediately interrupted. When called
  #    the current stack is provided to the function.
  #
  # Returns an array of strings. Each string is a tag that is still to be closed
  # (the most recent non closed tag is at the end of the array).
  parseFragment: (fragment, stack, matchExpr, cond) ->
    match = fragment.match(matchExpr)
    while match && cond(stack)
      if SELF_CLOSING_TAGS.indexOf(match[1]) < 0
        topElem = stack[stack.length-1]

        if match[2] && topElem == match[2]
          stack.pop()
        else
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
    stack = []
    matchExpr = /<(\w+)|<\/(\w*)/
    stack = @parseFragment( fragment, stack, matchExpr, (x) -> true )

    stack

  # Parses the given fragment of html code and returns true if the given tag
  # has a matching closing tag in it. If tag is reopened and reclosed in the
  # given fragment then the end point of that pair does not count as a matching
  # closing tag.
  tagDoesNotCloseInFragment: ( tags, fragment ) ->
    stack = tags
    stackLength = stack.length
    tag = tags[tags.length-1]
    matchExpr = new RegExp( "<(" + tag + ")|<\/(" + tag + ")" )
    stack = @parseFragment( fragment, stack, matchExpr, (s) ->
      s.length >= stackLength || s[s.length-1] == tag )

    stack.length > 0 && stack[stack.length-1] == tag

  # Parses preFragment and postFragment returning the last open tag in
  # preFragment that is not closed in postFragment.
  #
  # Returns a tag name or null if it can't find it.
  closingTagForFragments: (preFragment, postFragment) ->
    tags = @tagsNotClosedInFragment( preFragment )
    tag = tags[tags.length-1]
    if @tagDoesNotCloseInFragment( tags, postFragment )
      return tag
    else
      return null
