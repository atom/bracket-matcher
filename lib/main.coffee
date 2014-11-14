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
    atom.workspace.observeTextEditors (editor) ->
      editorElement = atom.views.getView(editor)
      new BracketMatcherView(editor, editorElement)
      new BracketMatcher(editor, editorElement)
