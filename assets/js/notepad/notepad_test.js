goog.provide('notepad_test');

goog.require('goog.dom');
goog.require('notepad.Note');

goog.require('goog.testing.jsunit');

function testNote() {
  var data = {title: 'note title', content: 'note content'};
  var container = goog.dom.createDom('testContainer');

  var note = new notepad.Note(data, container);

  assertEquals(data.title, note.title);
  assertEquals(data.content, note.content);
  assertEquals("Parent container", container, note.parent);
};
