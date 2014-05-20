BracketMatcher = require './bracket-matcher'
BracketMatcherView = require './bracket-matcher-view'

module.exports =
  configDefaults:
    autocompleteBrackets: true
    wrapSelectionsInBrackets: true

  activate: ->
    atom.workspaceView.eachEditorView (editorView) ->
      if editorView.attached and editorView.getPane()?
        new BracketMatcherView(editorView)
        new BracketMatcher(editorView)
