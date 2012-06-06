// This file was automatically generated from notepad.soy.
// Please don't edit this file by hand.

goog.provide('notepad.soy');

goog.require('soy');
goog.require('soy.StringBuilder');


/**
 * @param {Object.<string, *>=} opt_data
 * @param {soy.StringBuilder=} opt_sb
 * @return {string}
 * @notypecheck
 */
notepad.soy.helloName = function(opt_data, opt_sb) {
  var output = opt_sb || new soy.StringBuilder();
  if (! opt_data.greetingWord) {
    /** @desc Simple greeting */
    var MSG_UNNAMED_19 = goog.getMsg(
        'Hello {$name}. Welcome',
        {'name': soy.$$escapeHtml(opt_data.name)});
    output.append(MSG_UNNAMED_19, '!');
  } else {
    output.append(soy.$$escapeHtml(opt_data.greetingWord), ' ', soy.$$escapeHtml(opt_data.name), '!');
  }
  return opt_sb ? '' : output.toString();
};
