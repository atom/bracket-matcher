BracketMatcherView = null
BracketMatcher = null

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
    showBracketsInGutter:
      type: 'boolean'
      default: false

  activate: ->
    atom.workspace.observeTextEditors (editor) ->
      editorElement = atom.views.getView(editor)

      BracketMatcherView ?= require './bracket-matcher-view'
      new BracketMatcherView(editor, editorElement)

      BracketMatcher ?= require './bracket-matcher'
      new BracketMatcher(editor, editorElement)
