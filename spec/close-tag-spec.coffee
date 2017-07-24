TagFinder = require '../lib/tag-finder'
tagFinder = new TagFinder()

describe 'closeTag', ->
  describe 'TagFinder::parseFragment', ->
    fragment = ""

    beforeEach ->
      fragment = "<html><head><body></body>"

    it 'returns the last not closed elem in fragment, matching a given pattern', ->
      stack = tagFinder.parseFragment fragment, [], /<(\w+)|<\/(\w*)/, -> true
      expect(stack[stack.length - 1]).toBe("head")

    it 'stops when cond become true',  ->
      stack = tagFinder.parseFragment fragment, [], /<(\w+)|<\/(\w*)/, -> false
      expect(stack.length).toBe(0)

    it 'uses the given match expression to match tags', ->
      stack = tagFinder.parseFragment fragment, [], /<(body)|(notag)/, -> true
      expect(stack[stack.length - 1]).toBe("body")

  describe 'TagFinder::tagsNotClosedInFragment', ->
    it 'returns the outermost tag not closed in an HTML fragment', ->
      fragment = "<html><head></head><body><h1><p></p>"
      tags = tagFinder.tagsNotClosedInFragment(fragment)
      expect(tags).toEqual(['html', 'body', 'h1'])

    it 'is not confused by tag attributes', ->
      fragment = '<html><head></head><body class="c"><h1 class="p"><p></p>'
      tags = tagFinder.tagsNotClosedInFragment(fragment)
      expect(tags).toEqual(['html', 'body', 'h1'])

    it 'is not confused by namespace prefixes', ->
      fragment = '<xhtml:html><xhtml:body><xhtml:h1>'
      tags = tagFinder.tagsNotClosedInFragment(fragment)
      expect(tags).toEqual(['xhtml:html', 'xhtml:body', 'xhtml:h1'])

  describe 'TagFinder::tagDoesNotCloseInFragment', ->
    it 'returns true if the given tag is not closed in the given fragment', ->
      fragment = "</other1></other2></html>"
      expect(tagFinder.tagDoesNotCloseInFragment("body", fragment)).toBe(true)

    it 'returns false if the given tag is closed in the given fragment', ->
      fragment = "</other1></body></html>"
      expect(tagFinder.tagDoesNotCloseInFragment(["body"], fragment)).toBe(false)

    it 'returns true even if the given tag is re-opened and re-closed', ->
      fragment = "<other> </other><body></body><html>"
      expect(tagFinder.tagDoesNotCloseInFragment(["body"], fragment)).toBe(true)

    it 'returns false even if the given tag is re-opened and re-closed before closing', ->
      fragment = "<other> </other><body></body></body><html>"
      expect(tagFinder.tagDoesNotCloseInFragment(["body"], fragment)).toBe(false)

  describe 'TagFinder::closingTagForFragments', ->
    it 'returns the last opened in preFragment tag that is not closed in postFragment', ->
      preFragment = "<html><head></head><body><h1></h1><p>"
      postFragment = "</body></html>"
      expect(tagFinder.closingTagForFragments(preFragment, postFragment)).toBe("p")

    it 'correctly handles empty postFragment', ->
      preFragment = "<html><head></head><body><h1></h1><p>"
      postFragment = ""
      expect(tagFinder.closingTagForFragments(preFragment, postFragment)).toBe("p")

    it "correctly handles malformed tags", ->
      preFragment = "<html><head></head></htm"
      postFragment = ""
      expect(tagFinder.closingTagForFragments(preFragment, postFragment)).toBe("html")

    it 'returns null if there is no open tag to be closed', ->
      preFragment = "<html><head></head><body><h1></h1><p>"
      postFragment = "</p></body></html>"
      expect(tagFinder.closingTagForFragments(preFragment, postFragment)).toBe(null)

    it "correctly closes tags containing hyphens", ->
      preFragment = "<html><head></head><body><h1></h1><my-element>"
      postFragment = "</body></html>"
      expect(tagFinder.closingTagForFragments(preFragment, postFragment)).toBe("my-element")

    it 'correctly closes tags when there are other tags with the same prefix', ->
      preFragment = "<thead><th>"
      postFragment = "</thead>"
      expect(tagFinder.closingTagForFragments(preFragment, postFragment)).toBe("th")
