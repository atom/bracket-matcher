BracketMatcher = require './bracket-matcher'
BracketMatcherView = require './bracket-matcher-view'

module.exports =
  configDefaults:
    autocompleteBrackets: true
    autocompleteSmartQuotes: true
    wrapSelectionsInBrackets: true

  activate: ->
    atom.workspaceView.eachEditorView (editorView) ->
      if editorView.attached and editorView.getPaneView()?
        BracketMatcherView.create(editorView)
        new BracketMatcher(editorView)
