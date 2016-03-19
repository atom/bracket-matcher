BracketMatcherView = null
BracketMatcher = null

module.exports =
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
