BracketMatcherView = null
BracketMatcher = null

module.exports =
  config:
    autocompleteBrackets:
      type: 'boolean'
      default: true
      description: 'Autocomplete bracket and quote characters, such as `(` and `)`, and `"`.'
    autocompleteSmartQuotes:
      type: 'boolean'
      default: true
      description: 'Autocomplete smart quote characters, such as `“` and `”`, and `«` and `»`.'
    wrapSelectionsInBrackets:
      type: 'boolean'
      default: true
      description: 'Wrap selected text in brackets or quotes when the editor contains selections and the opening bracket or quote is typed.'
    wrapSelectionsInMarkdownPunctuation:
      type: 'boolean'
      default: true
      description: 'Wrap selected text in *, _, or ~ when the editor contains selections those characters are typed.'

  activate: ->
    atom.workspace.observeTextEditors (editor) ->
      editorElement = atom.views.getView(editor)

      BracketMatcherView ?= require './bracket-matcher-view'
      new BracketMatcherView(editor, editorElement)

      BracketMatcher ?= require './bracket-matcher'
      new BracketMatcher(editor, editorElement)
