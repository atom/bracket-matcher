BracketMatcher = require './bracket-matcher'
BracketMatcherView = require './bracket-matcher-view'

module.exports =
  config:
    autocompleteBrackets:
      type: 'boolean'
      default: true
    autocompleteSmartQuotes:
      type: 'boolean'
      default: true
    wrapSelectionsInBrackets:
      type: 'boolean'
      default: true

  activate: ->
    atom.workspaceView.eachEditorView (editorView) ->
      if editorView.attached and editorView.getPaneView()?
        new BracketMatcherView(editorView)
        new BracketMatcher(editorView)
