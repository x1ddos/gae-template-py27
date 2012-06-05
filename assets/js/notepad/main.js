goog.provide('notepad.start');

goog.require('notepad.Note');
goog.require('notepad.makeNotes');

goog.require('goog.events');
goog.require('goog.ui.Css3ButtonRenderer');
goog.require('goog.ui.decorate');

notepad.start = function(container, newNoteBtn) {
	var noteData = [
    {'title': 'Note 1', 'content': 'Content of Note 1'},
    {'title': 'Note 2', 'content': 'Content of Note 2'}];

	var noteListElement = document.getElementById(container);
	notepad.makeNotes(noteData, noteListElement);

	var btn = goog.ui.decorate(goog.dom.getElement(newNoteBtn));
	goog.events.listen(btn, goog.ui.Component.EventType.ACTION,
		function(e) {
		  var noteTitle = window.prompt('Note title:');
			if (noteTitle) {
				var data = {'title': noteTitle, 'content': 'New note content'};
				var note = new notepad.Note(data, noteListElement);
				note.makeNoteDom();
				note.edit();
			}
	});
}

// Ensures the symbol will be visible after compiler renaming.
goog.exportSymbol('notepad.start', notepad.start);
