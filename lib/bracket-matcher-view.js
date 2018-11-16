const {CompositeDisposable} = require('atom')
const _ = require('underscore-plus')
const {Range, Point} = require('atom')
const TagFinder = require('./tag-finder')

const MAX_ROWS_TO_SCAN = 10000
const ONE_CHAR_FORWARD_TRAVERSAL = Object.freeze(Point(0, 1))
const ONE_CHAR_BACKWARD_TRAVERSAL = Object.freeze(Point(0, -1))
const TWO_CHARS_BACKWARD_TRAVERSAL = Object.freeze(Point(0, -2))
const MAX_ROWS_TO_SCAN_FORWARD_TRAVERSAL = Object.freeze(Point(MAX_ROWS_TO_SCAN, 0))
const MAX_ROWS_TO_SCAN_BACKWARD_TRAVERSAL = Object.freeze(Point(-MAX_ROWS_TO_SCAN, 0))

module.exports =
class BracketMatcherView {
  constructor (editor, editorElement, matchManager) {
    this.destroy = this.destroy.bind(this)
    this.updateMatch = this.updateMatch.bind(this)
    this.editor = editor
    this.matchManager = matchManager
    this.gutter = this.editor.gutterWithName('line-number')
    this.subscriptions = new CompositeDisposable()
    this.tagFinder = new TagFinder(this.editor)
    this.pairHighlighted = false
    this.tagHighlighted = false
    // ranges for possible selection
    this.bracket1Range = null
    this.bracket2Range = null

    this.subscriptions.add(
      this.editor.onDidTokenize(this.updateMatch),
      this.editor.getBuffer().onDidChangeText(this.updateMatch),
      this.editor.onDidChangeGrammar(this.updateMatch),
      this.editor.onDidChangeSelectionRange(this.updateMatch),
      this.editor.onDidAddCursor(this.updateMatch),
      this.editor.onDidRemoveCursor(this.updateMatch),

      atom.commands.add(editorElement, 'bracket-matcher:go-to-matching-bracket', () =>
        this.goToMatchingPair()
      ),

      atom.commands.add(editorElement, 'bracket-matcher:go-to-enclosing-bracket', () =>
        this.goToEnclosingPair()
      ),

      atom.commands.add(editorElement, 'bracket-matcher:select-inside-brackets', () =>
        this.selectInsidePair()
      ),

      atom.commands.add(editorElement, 'bracket-matcher:close-tag', () =>
        this.closeTag()
      ),

      atom.commands.add(editorElement, 'bracket-matcher:remove-matching-brackets', () =>
        this.removeMatchingBrackets()
      ),

      atom.commands.add(editorElement, 'bracket-matcher:select-matching-brackets', () =>
        this.selectMatchingBrackets()
      ),

      this.editor.onDidDestroy(this.destroy)
    )

    this.updateMatch()
  }

  destroy () {
    this.subscriptions.dispose()
  }

  updateMatch () {
    if (this.pairHighlighted) {
      this.editor.destroyMarker(this.startMarker.id)
      this.editor.destroyMarker(this.endMarker.id)
    }

    this.pairHighlighted = false
    this.tagHighlighted = false

    if (!this.editor.getLastSelection().isEmpty()) return

    let matchPosition
    let {position, currentPair, matchingPair} = this.findCurrentPair(false)
    if (position) {
      matchPosition = this.findMatchingEndPair(position, currentPair, matchingPair)
    } else {
      ({position, currentPair, matchingPair} = this.findCurrentPair(true))
      if (position) {
        matchPosition = this.findMatchingStartPair(position, matchingPair, currentPair)
      }
    }

    let startRange = null
    let endRange = null
    let highlightTag = false
    let highlightPair = false
    if (position && matchPosition) {
      this.bracket1Range = (startRange = Range(position, position.traverse(ONE_CHAR_FORWARD_TRAVERSAL)))
      this.bracket2Range = (endRange = Range(matchPosition, matchPosition.traverse(ONE_CHAR_FORWARD_TRAVERSAL)))
      highlightPair = true
    } else {
      this.bracket1Range = null
      this.bracket2Range = null
      let pair = this.tagFinder.findMatchingTags()
      if (pair) {
        ({startRange, endRange} = pair)
        highlightTag = true
        highlightPair = true
      }
    }

    if (!highlightTag && !highlightPair) return
    if (this.editor.isFoldedAtCursorRow()) return
    if (this.isCursorOnCommentOrString()) return

    this.startMarker = this.createMarker(startRange)
    this.endMarker = this.createMarker(endRange)
    this.pairHighlighted = highlightPair
    this.tagHighlighted = highlightTag
  }

  selectMatchingBrackets () {
    if (!this.bracket1Range && !this.bracket2Range) return
    this.editor.setSelectedBufferRanges([this.bracket1Range, this.bracket2Range])
    this.matchManager.changeBracketsMode = true
  }

  removeMatchingBrackets () {
    if (this.editor.hasMultipleCursors()) {
      this.editor.backspace()
      return
    }

    this.editor.transact(() => {
      if (this.editor.getLastSelection().isEmpty()) {
        this.editor.selectLeft()
      }

      const text = this.editor.getSelectedText()
      this.editor.moveRight()

      // check if the character to the left is part of a pair
      if (this.matchManager.pairedCharacters.hasOwnProperty(text) || this.matchManager.pairedCharactersInverse.hasOwnProperty(text)) {
        let matchPosition
        let {position, currentPair, matchingPair} = this.findCurrentPair(false)
        if (position) {
          matchPosition = this.findMatchingEndPair(position, currentPair, matchingPair)
        } else {
          ({position, currentPair, matchingPair} = this.findCurrentPair(true))
          if (position) {
            matchPosition = this.findMatchingStartPair(position, matchingPair, currentPair)
          }
        }

        if (position && matchPosition) {
          this.editor.setCursorBufferPosition(matchPosition)
          this.editor.delete()
          // if on the same line and the cursor is in front of an end pair
          // offset by one to make up for the missing character
          if ((position.row === matchPosition.row) && this.matchManager.pairedCharactersInverse.hasOwnProperty(currentPair)) {
            position = position.traverse(ONE_CHAR_BACKWARD_TRAVERSAL)
          }
          this.editor.setCursorBufferPosition(position)
          this.editor.delete()
        } else {
          this.editor.backspace()
        }
      } else {
        this.editor.backspace()
      }
    })
  }

  findMatchingEndPair (startPairPosition, startPair, endPair) {
    if (
      startPair === endPair ||
      this.isScopeCommentedOrString(this.editor.scopeDescriptorForBufferPosition(startPairPosition).getScopesArray())
    ) return

    const scanRange = new Range(
      startPairPosition.traverse(ONE_CHAR_FORWARD_TRAVERSAL),
      startPairPosition.traverse(MAX_ROWS_TO_SCAN_FORWARD_TRAVERSAL)
    )
    let endPairPosition = null
    let unpairedCount = 0
    this.editor.scanInBufferRange(this.matchManager.pairRegexes[startPair], scanRange, result => {
      if (this.isRangeCommentedOrString(result.range)) return
      switch (result.match[0]) {
        case startPair:
          unpairedCount++
          break
        case endPair:
          unpairedCount--
          if (unpairedCount < 0) {
            endPairPosition = result.range.start
            result.stop()
          }
          break
      }
    })

    return endPairPosition
  }

  findMatchingStartPair (endPairPosition, startPair, endPair) {
    if ((startPair === endPair) || this.isScopeCommentedOrString(this.editor.scopeDescriptorForBufferPosition(endPairPosition).getScopesArray())) return

    const scanRange = new Range(
      endPairPosition.traverse(MAX_ROWS_TO_SCAN_BACKWARD_TRAVERSAL),
      endPairPosition
    )
    let startPairPosition = null
    let unpairedCount = 0
    this.editor.backwardsScanInBufferRange(this.matchManager.pairRegexes[startPair], scanRange, result => {
      if (this.isRangeCommentedOrString(result.range)) return
      switch (result.match[0]) {
        case startPair:
          unpairedCount--
          if (unpairedCount < 0) {
            startPairPosition = result.range.start
            result.stop()
            break
          }
          break
        case endPair:
          unpairedCount++
      }
    })

    return startPairPosition
  }

  findAnyStartPair (cursorPosition) {
    const scanRange = new Range(Point.ZERO, cursorPosition)
    const startPair = _.escapeRegExp(_.keys(this.matchManager.pairedCharacters).join(''))
    const endPair = _.escapeRegExp(_.keys(this.matchManager.pairedCharactersInverse).join(''))
    const combinedRegExp = new RegExp(`[${startPair}${endPair}]`, 'g')
    const startPairRegExp = new RegExp(`[${startPair}]`, 'g')
    const endPairRegExp = new RegExp(`[${endPair}]`, 'g')
    let startPosition = null
    let unpairedCount = 0
    this.editor.backwardsScanInBufferRange(combinedRegExp, scanRange, result => {
      if (this.isRangeCommentedOrString(result.range)) return
      if (result.match[0].match(endPairRegExp)) {
        unpairedCount++
      } else if (result.match[0].match(startPairRegExp)) {
        unpairedCount--
        if (unpairedCount < 0) {
          startPosition = result.range.start
          result.stop()
        }
      }
    })

    return startPosition
  }

  createMarker (bufferRange) {
    const marker = this.editor.markBufferRange(bufferRange)
    this.editor.decorateMarker(marker, {type: 'highlight', class: 'bracket-matcher', deprecatedRegionClass: 'bracket-matcher'})
    if (atom.config.get('bracket-matcher.highlightMatchingLineNumber', {scope: this.editor.getRootScopeDescriptor()}) && this.gutter) {
      this.gutter.decorateMarker(marker, {type: 'highlight', class: 'bracket-matcher', deprecatedRegionClass: 'bracket-matcher'})
    }
    return marker
  }

  findCurrentPair (isInverse) {
    let matches, matchingPair
    let position = this.editor.getCursorBufferPosition()
    if (isInverse) {
      matches = this.matchManager.pairedCharactersInverse
      position = position.traverse(ONE_CHAR_BACKWARD_TRAVERSAL)
    } else {
      matches = this.matchManager.pairedCharacters
    }
    let currentPair = this.editor.getTextInRange(Range.fromPointWithDelta(position, 0, 1))
    if (!matches[currentPair]) {
      if (isInverse) {
        position = position.traverse(ONE_CHAR_FORWARD_TRAVERSAL)
      } else {
        position = position.traverse(ONE_CHAR_BACKWARD_TRAVERSAL)
      }
      currentPair = this.editor.getTextInRange(Range.fromPointWithDelta(position, 0, 1))
    }
    if ((matchingPair = matches[currentPair])) {
      return {position, currentPair, matchingPair}
    } else {
      return {}
    }
  }

  goToMatchingPair () {
    if (!this.pairHighlighted) return this.goToEnclosingPair()
    const position = this.editor.getCursorBufferPosition()

    if (this.tagHighlighted) {
      let tagCharacterOffset
      let startRange = this.startMarker.getBufferRange()
      const tagLength = startRange.end.column - startRange.start.column
      let endRange = this.endMarker.getBufferRange()
      if (startRange.compare(endRange) > 0) {
        [startRange, endRange] = [endRange, startRange]
      }

      // include the <
      startRange = new Range(startRange.start.traverse(ONE_CHAR_BACKWARD_TRAVERSAL), endRange.end.traverse(ONE_CHAR_BACKWARD_TRAVERSAL))
      // include the </
      endRange = new Range(endRange.start.traverse(TWO_CHARS_BACKWARD_TRAVERSAL), endRange.end.traverse(TWO_CHARS_BACKWARD_TRAVERSAL))

      if (position.isLessThan(endRange.start)) {
        tagCharacterOffset = position.column - startRange.start.column
        if (tagCharacterOffset > 0) { tagCharacterOffset++ }
        tagCharacterOffset = Math.min(tagCharacterOffset, tagLength + 2) // include </
        this.editor.setCursorBufferPosition(endRange.start.traverse([0, tagCharacterOffset]))
      } else {
        tagCharacterOffset = position.column - endRange.start.column
        if (tagCharacterOffset > 1) { tagCharacterOffset-- }
        tagCharacterOffset = Math.min(tagCharacterOffset, tagLength + 1) // include <
        this.editor.setCursorBufferPosition(startRange.start.traverse([0, tagCharacterOffset]))
      }
    } else {
      const previousPosition = position.traverse(ONE_CHAR_BACKWARD_TRAVERSAL)
      const startPosition = this.startMarker.getStartBufferPosition()
      const endPosition = this.endMarker.getStartBufferPosition()

      if (position.isEqual(startPosition)) {
        this.editor.setCursorBufferPosition(endPosition.traverse(ONE_CHAR_FORWARD_TRAVERSAL))
      } else if (previousPosition.isEqual(startPosition)) {
        this.editor.setCursorBufferPosition(endPosition)
      } else if (position.isEqual(endPosition)) {
        this.editor.setCursorBufferPosition(startPosition.traverse(ONE_CHAR_FORWARD_TRAVERSAL))
      } else if (previousPosition.isEqual(endPosition)) {
        this.editor.setCursorBufferPosition(startPosition)
      }
    }
  }

  goToEnclosingPair () {
    if (this.pairHighlighted) return

    const matchPosition = this.findAnyStartPair(this.editor.getCursorBufferPosition())
    if (matchPosition) {
      this.editor.setCursorBufferPosition(matchPosition)
    } else {
      const pair = this.tagFinder.findEnclosingTags()
      if (pair) {
        let {startRange, endRange} = pair
        if (startRange.compare(endRange) > 0) {
          [startRange, endRange] = [endRange, startRange]
        }
        this.editor.setCursorBufferPosition(startRange.start)
      }
    }
  }

  selectInsidePair () {
    let endPosition, endRange, startPosition, startRange
    if (this.pairHighlighted) {
      startRange = this.startMarker.getBufferRange()
      endRange = this.endMarker.getBufferRange()

      if (this.tagHighlighted) {
        // NOTE: findEnclosingTags is not used as it has a scope check
        // that will fail on very long lines
        ({startRange, endRange} = this.tagFinder.findStartEndTags(true))
      }

      if (startRange.compare(endRange) > 0) {
        [startRange, endRange] = [endRange, startRange]
      }

      startPosition = startRange.end
      endPosition = endRange.start
    } else {
      startPosition = this.findAnyStartPair(this.editor.getCursorBufferPosition())
      if (startPosition) {
        const startPair = this.editor.getTextInRange(Range.fromPointWithDelta(startPosition, 0, 1))
        endPosition = this.findMatchingEndPair(startPosition, startPair, this.matchManager.pairedCharacters[startPair])
        startPosition = startPosition.traverse([0, 1])
      } else {
        const pair = this.tagFinder.findStartEndTags(true)
        if (pair) {
          // NOTE: findEnclosingTags is not used as it has a scope check
          // that will fail on very long lines
          ({startRange, endRange} = pair)
          if (startRange.compare(endRange) > 0) {
            [startRange, endRange] = [endRange, startRange]
          }

          startPosition = startRange.end
          endPosition = endRange.start
        }
      }
    }

    if (startPosition && endPosition) {
      const rangeToSelect = new Range(startPosition, endPosition)
      this.editor.setSelectedBufferRange(rangeToSelect)
    }
  }

  // Insert at the current cursor position a closing tag if there exists an
  // open tag that is not closed afterwards.
  closeTag () {
    const cursorPosition = this.editor.getCursorBufferPosition()
    const preFragment = this.editor.getTextInBufferRange([Point.ZERO, cursorPosition])
    const postFragment = this.editor.getTextInBufferRange([cursorPosition, Point.INFINITY])

    const tag = this.tagFinder.closingTagForFragments(preFragment, postFragment)
    if (tag) {
      this.editor.insertText(`</${tag}>`)
    }
  }

  isCursorOnCommentOrString () {
    return this.isScopeCommentedOrString(this.editor.getLastCursor().getScopeDescriptor().getScopesArray())
  }

  isRangeCommentedOrString (range) {
    return this.isScopeCommentedOrString(this.editor.scopeDescriptorForBufferPosition(range.start).getScopesArray())
  }

  isScopeCommentedOrString (scopesArray) {
    for (let scope of scopesArray.reverse()) {
      scope = scope.split('.')
      if (scope.includes('embedded') && scope.includes('source')) return false
      if (scope.includes('comment') || scope.includes('string')) return true
    }

    return false
  }
}
