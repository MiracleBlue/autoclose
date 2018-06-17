{CompositeDisposable} = require 'atom'

module.exports =
  subscriptions: null
  currentEditor: null
  action: null
  extension: ''
  disabledFileExtensions: []
  config:
    disabledFileExtensions:
      type: 'array',
      default: ['js', 'jsx'],
      description: 'Disabled autoclose in above file types'

  activate: ->
    @subscriptions = new CompositeDisposable
    atom.config.observe 'autoclose.disabledFileExtensions', (value) =>
      @disabledFileExtensions = value

    @currentEditor = atom.workspace.getActiveTextEditor()
    if @currentEditor
      @action = @currentEditor.onDidInsertText (event) =>
        @_closeTag(event)
    @_getFileExtension()
    atom.workspace.onDidChangeActivePaneItem (paneItem) =>
      @_paneItemChanged(paneItem)

  deactivate: ->
    if @action then @action.disposalAction()
    @subscriptions.dispose()

  _getFileExtension: ->
    filename = @currentEditor?.getFileName?()
    @extension = filename?.substr filename?.lastIndexOf('.') + 1

  _paneItemChanged: (paneItem) ->
    if !paneItem then return

    if @action then @action.disposalAction()
    @currentEditor = paneItem
    @_getFileExtension()
    if @currentEditor.onDidInsertText
      @action = @currentEditor.onDidInsertText (event) =>
        @_closeTag(event)

  _addIndent: (range) ->
    {start, end} = range
    buffer = @currentEditor.buffer
    lineBefore = buffer.getLines()[start.row]
    lineAfter = buffer.getLines()[end.row]
    content = lineBefore.substr(lineBefore.lastIndexOf('<')) + '\n' + lineAfter
    regex = ///
              ^.*\<([a-zA-Z0-9-_]+)(\s.+)?\>
              \n
              \s*\<\/\1\>.*
            ///

    if regex.test content
      @currentEditor.insertNewlineAbove()

  _closeTag: (event) ->
    {text, range} = event
    if text is '\n'
      @_addIndent event.range
      return

    return if text isnt '>' and text isnt '/'

    line = @currentEditor.buffer.getLines()[range.end.row]
    strBefore = line.substr 0, range.start.column
    strAfter = line.substr range.end.column
    previousTagIndex = strBefore.lastIndexOf('<')
    previousCloseIndex = strBefore.lastIndexOf('>');

    if previousCloseIndex > previousTagIndex
      return

    if previousTagIndex < 0
      return
    
    tagString = strBefore.substr previousTagIndex
    openedQuotes = (tagString.match(/"/g) || []).length % 2
    openedCurly = (tagString.match(/={/g) || []).length != (tagString.match(/}/g) || []).length
    if openedQuotes or openedCurly then return

    tagName = strBefore.match(/^.*\<([a-zA-Z0-9-_.]+)[^>]*?/)?[1]
    if !tagName then return

    if text is '>' and tagName is 'input'
      return  
    else if text is '>'
      if strBefore[strBefore.length - 1] is '/'
        return

      @currentEditor.insertText "</#{tagName}>"
      @currentEditor.moveLeft tagName.length + 3
    else if text is '/'
      if strAfter[0] is '>' then return
      @currentEditor.insertText '>'
