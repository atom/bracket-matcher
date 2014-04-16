BracketMatcher = require './bracket-matcher'
BracketMatcherView = require './bracket-matcher-view'

module.exports =
  activate: ->
    atom.workspaceView.eachEditorView (editorView) ->
      if editorView.attached and editorView.getPane()?
        new BracketMatcherView(editorView)

    atom.workspace.eachEditor (editor) ->
      new BracketMatcher(editor)
