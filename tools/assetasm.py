# -*- coding: utf-8 -*-
"""Static assets and (HTML) templates builder/compiler.

For static assets, this script can recursively walk a directory with
Javascripts, CSS and images, translating them into "hashed" versions, 
based on their content, e.g.

img/image.png => img/image-<some-md5-hash>.png


For HTML templates, the script can translate references to the above
static assets, e.g. with their hashed versions.

The translation is based on data-compile attirbutes of HTML tags
in the templates.

- to remove a tag use `data-build="remove"`

  <script src="/js/closure/goog/base.js" data-build="remove"></script>

- to replace an asset reference with its hashed version
  no specific attributes needed, all URL present in static
  assets manifest will be replaced with hashed versions, e.g.

  <script src="/js/compiled.js" 
  translates into src="/js/compiled_<md5-hash>.js"

  <link href="/css/compiled.css"
  translates into href="/css/compiled_<md5-hash>.css"

  <img src="/img/image.png" 
  translates into src="/img/image_<md5-hash>.png"

- to translate a reference into another path AND hashify
  use `data-build="tr:/another/path"`

  <link href="/css/compiled_debug.css" data-build="tr:/css/compiled.css">
  translates into href="/css/compiled_<md5-hash>.js"

- to compress inline scripts use `data-build="compress"`

  <script data-build="compress">
    ...some javascript code goes here...
  </script>

  Don't forget to provide --compiler-jar script option.

- <!-- comments --> and `data-build` attributes will be stripped

Alway place data-build as the last attribute of a tag.


Command line arguments:
  [-h] <what> <cmd> <options>

what:
  "static"        - work only with static assets
  "templates"     - work with HTML/Jinja templates. This implies
                    bulding static assets too (if needed)
cmd:
  "manifest"  will list all hashed version of assets in JSON format.
  "check"     will check changes in the src tree and exit with -1, if any.
              This is an expensive operation if used with 
              "all" or "templates" command.
  "build"     invokes the actual building/compression/translation.

Run the script with `-h` for available options.

"""

import os
import sys
import glob
import argparse
import logging

import re
import hashlib
import json

# matching with search()
_RE_IGNORE = [
  re.compile('^(.*/)?\..*'),
  re.compile('.*\.gss$'),
  re.compile('js/cssmap.*'),
  re.compile('.*\.soy$'),
  re.compile('^(.*/)?soyutils.*\.js'),
  re.compile('^(.*/)?deps\.js'),
  re.compile('.*\_tests?.(html|js)$'),
  re.compile('.*\_debug?.(html|js|css)$'),
  re.compile('.*closure(-lib)?')
]

_RE_SKIP_HASH = [
  re.compile('^(.*/)?favicon.*\..+$'),
  re.compile('^(.*/)?apple-touch-.*\.png$'),
]

# Additional arguments to json.dump()
_JSON_DUMP_ARGS = {'skipkeys': True, 'indent': 2}


#
# Template chunks extractor
#

class Replacer(object):
  """
  Replaces fragments of text using regexp
  """
  def __init__(self, data):
    self.data = data

  def replace(self, replmap):
    """
    Replaces all urls from replmap tuples.
    replmap is a list of (url, replacement) tuples"
    """
    for src, repl in replmap:
      pattern = re.escape(src)
      self.data = re.sub(pattern, repl, self.data, re.DOTALL)

  def remove(self, *patterns):
    """
    Similar to replace() but substitutes provided patterns 
    with empty strings
    """
    for p in patterns:
      if isinstance(p, basestring):
        self.data = re.sub(p, '', self.data, re.DOTALL | re.M)
      else:
        self.data = p.sub('', self.data)

  def transform(self, regex, cgroup, template, callback):
    """Transforms a string fragment by invoking callback.

    Args:
      regex: RegexObject to search on
      cgroup: content group
      template: string that will be expanded for substituion
      callback: a function that will be called with matched.group(cgroup)
                argument
    """
    while True:
      m = regex.search(self.data)
      if not m: break

      content = m.group(cgroup)
      repl = m.expand(template % callback(content))
      self.data = u''.join([
        self.data[:m.start()], repl, self.data[m.end():]
      ])      


#
# Simple filesystem walker
#

class FilesListBuilder(object):
  """A class that can build a list of files"""

  def __init__(self, root, ignore=[]):
    """Constructor.

    Args:
      root: a staring point
      ignore: a list of ignore patterns (re.compile() objects)

    """
    self.__root = os.path.normpath(root) + '/'
    self._ignore_patterns = ignore

  @property
  def root(self):
    return self.__root

  def walk(self):
    """Starts walking recursively from root.

    Returns:
      a list of tuples (filepath, timestamp, size), where root part 
      is removed. For instance assets/js/file.js will become js/file.js.
    """ 
    fileslist = []
    for curdir, subdirs, files in os.walk(self.root):
      for fname in files:
        filepath = os.path.join(curdir, fname)
        if not self._should_ignore(filepath):
          stat = os.stat(filepath)
          stripped = filepath.replace(self.root, '', 1)
          asset = (stripped, int(stat.st_mtime), stat.st_size)
          fileslist.append(asset)
    return fileslist

  def _should_ignore(self, path):
    """Returns true if filename matches ignore pattern"""
    for regex in self._ignore_patterns:
      if regex.search(path) is not None:
        return True
    return False


#
# Abstract builder
#

class AbstractBuilder(object):
  """Abstract builder for HTML templates and static assets"""

  def __init__(self, src, dst, dirwalker=FilesListBuilder, 
    ignore_patterns=[], skip_hash=[], compiler_jar=None):
    """Constructor.

    Args:
      src: root for source files
      dst: root for build output
      dirwalker: a class that knows how to walk directories recursively.
        It should accept (root, ignore_patterns_list) in constructor,
        and have a walk() method that would return a list of files to process.
      ignore_patterns: a list of path patterns to completely ignore.
      skip_hash: a list of path patterns that shouldn't be hashified.
      compiler_jar: path to compiler.jar

    """
    self.__src = os.path.normpath(src)
    self.__dst = os.path.normpath(dst)
    self.__dirwalker = dirwalker(self.src, ignore_patterns)
    self.__compiler_jar = compiler_jar
    self._skip_hash = skip_hash
    self._out = sys.stdout
    self._err = sys.stderr
    self._logger = logging.getLogger(self.__class__.__name__)

  @property
  def src(self):
    return self.__src

  @property
  def dst(self):
    return self.__dst

  @property
  def dirwalker(self):
    """Source directory recursive walker"""
    return self.__dirwalker

  @property
  def compiler_cmd(self):
    """Returns a list of args for Popen() to run compiler.jar"""
    if not hasattr(self, '__compiler_cmd'):
      if self.__compiler_jar is None:
        self.__compiler_cmd = None
      else:
        cmd = ['java', '-jar', self.__compiler_jar]
        cmd.append('--compilation_level=ADVANCED_OPTIMIZATIONS')
        self.__compiler_cmd = cmd
    return self.__compiler_cmd

  def do_manifest(self, output=None):
    """List all files with hashed version recursively, starting from src dir.

    This is a command-line method, it outputs results directly to writer.

    Args:
      output: any object that supports write(str). If not provided,
              an internal self._out will be used (usually sys.stdout)
    """
    json.dump(self.manifest(), output or self._out, **_JSON_DUMP_ARGS)

  def do_check(self):
    """
    For each entry in the manifest, outputs whether the source
    file has changes w.r.t. the latest built.

    Returns:
      true if there are no changes, false otherwise.

    """
    manifest = self.manifest()
    changed = False
    for f, info in manifest.items():
      if self._has_changes(f, info):
        self._err.write("** %s\n" % f)
        changed = True

    if changed:
      sys.exit(1)

  def do_build(self):
    """A command-line frontend for self.build()"""
    if not self.build():
      self._err.write("** Build failed\n")
      sys.exit(1)

  def manifest(self):
    """
    Creates a manifest object by walking src dir recursively.

    Returns:
      A manifest dict with file path as a key, timestamp, size and hash.

    """
    if not hasattr(self, '__manifest'):
      manifest = {}
      for path, ts, size in self.dirwalker.walk():
        filepath = os.path.join(self.src, path)
        manifest[path] = { 'ts': ts, 'size': size }
        if self._should_hash(filepath):
          manifest[path].update(hash=self._compute_hash(filepath))
      self.__manifest = manifest
    return self.__manifest

  def _should_hash(self, path):
    """Returns true if path matches _RE_SKIP_HASH"""
    for regex in self._skip_hash:
      if regex.search(path) is not None:
        return False
    return True

  def _compute_hash(self, filepath):
    """Computes SHA1 hash of a file located at root/path.

    Result is a hexdigest string divided in groups of 4.
    Hash format conforms to _HASH_PATTERN
    """
    h = hashlib.sha1()
    with open(filepath,'rb') as f: 
      for chunk in iter(lambda: f.read(8192), b''): 
           h.update(chunk)
    digest = h.hexdigest()
    return digest[:8]

  _HASH_PATTERN = '[a-z0-9]{8}'
  _HASH_SEPARATOR = '_'

  def _hashify_path(self, path, hashver):
    """Adds hashver to file path/name, e.g.

    css/compiled.css => css/compiled_<hashver>.css
    """
    parts = os.path.splitext(path)
    return ''.join([parts[0], self._HASH_SEPARATOR, hashver, parts[1]])

  def _hash_target_path(self, path, hashver):
    """Creates a target file path in this format:
    
    js/compiled.js => :target_dir/js/compiled_<hash>.js

    Args:
      path: file path, relative to dst dir
      hashver: string hash
    """
    hashed_path = self._hashify_path(path, hashver)
    return os.path.join(self.dst, hashed_path)

  def _ensure_dir(self, dirpath):
    """Creates a directory if it doesn't exist (as in mkdir -p)"""
    try:
      os.makedirs(dirpath)
    except OSError:
      pass

  def _read_contents(self, filepath, open_mode='r'):
    """
    Reads contents of the entire file, and rewinds 
    to the original file position
    """
    f = open(filepath, open_mode)
    pos = f.tell()
    contents = f.read()
    f.seek(pos) # rewind to the original pos
    f.close()
    return contents


#
# Static assets assembler, on top of Abstract builder
#

class StaticBuilder(AbstractBuilder):
  """Static assets builder.

  See module description for details.
  """
  def build(self, cleanup=True):
    """
    Builds out assets from src into dst. Does not touch those
    that haven't changed since the last build.

    Currently, it just copies files over, but filters could be 
    applied during coping.

    Args:
      cleanup: if true, will remove old hashed files (if any)

    Returns:
      an int > 0 if build process was successful, 0 otherwise
    """
    self._out.write("Static [%s] => [%s]\n" % (self.src, self.dst));

    assets_to_cleanup = []
    at_least_one = False
    for filepath, info in self.manifest().items():
      if self._has_changes(filepath, info):
        at_least_one = True
        srcpath = os.path.join(self.src, filepath)
        hashver = info.get('hash', None)
        if not hashver:
          dstpath = os.path.join(self.dst, filepath)
        else:
          dstpath = self._hash_target_path(filepath, hashver)
          
        self._process_asset(srcpath, dstpath)
        if cleanup and hashver: 
          assets_to_cleanup.append((filepath, hashver))

    # cleaning up after processing, to make sure we remove content
    # only if processing went fine.
    if cleanup:
      self._cleanup(assets_to_cleanup)

    return 1 + int(at_least_one)

  def _process_asset(self, src, target):
    """Actual asset processing. 

    Currenty, it makes a simple copy of src into target
    """
    self._out.write("** %s\n" % src)

    target_dir = os.path.dirname(target)
    self._ensure_dir(target_dir)

    contents = self._read_contents(src, 'rb')
    ftarget = open(target, 'wb')
    ftarget.write(contents)
    ftarget.close()

  def _cleanup(self, patterns):
    """Removes old assets from dst dir.

    Each item from patterns should be a tuple
    of (filepath, valid_hash), where filepath 
    is a relative file path, e.g.

    ('js/compiled.js', 'some_hash_version')

    """
    for filepath, hashver in patterns:
      exlude = self._hashify_path(filepath, hashver)
      parts = os.path.splitext(filepath)            # ('css/compiled', '.css')
      pattern = re.compile(''.join([
        re.escape(parts[0]), self._HASH_SEPARATOR, self._HASH_PATTERN, 
        re.escape(parts[1])
      ]))

      glob_pattern = '%s*%s' % (parts[0], parts[1]) # 'css/compiled*.css'
      path = os.path.join(self.dst, glob_pattern)

      for afile in glob.iglob(path):
        if not afile.endswith(exlude) and pattern.search(afile):
          self._out.write('-- deleting %s\n' % afile)
          os.remove(afile)

  def _has_changes(self, filepath, info):
    """Confronts src/filepath with target/filepath.
    Used by super class'es do_check().

    Args:
      filepath: a relative file path
      info: dict item from the manifest

    Returns:
      false if files are identical, true otherwise
    """
    hashver = info.get('hash', None)
    if hashver:
      dstfile = self._hash_target_path(filepath, hashver)
    else:
      dstfile = os.path.join(self.dst, filepath)

    if not os.path.exists(dstfile):
      return True

    stat = os.stat(dstfile)
    return info['ts'] > int(stat.st_mtime)


#
# Templates builder, on top of Abstract builder
#

class TemplatesBuilder(AbstractBuilder):
  """HTML templates builder.

  See module description for details.
  """
  def __init__(self, src, dst, static_builder, **kwargs):
    super(TemplatesBuilder, self).__init__(src, dst, **kwargs)
    self.__static_builder = static_builder

  @property
  def static(self):
    """Static builder instance"""
    return self.__static_builder

  def build(self):
    """Compiles HTML templates. See module's description."""
    # rebuilt > 1 means static assets were rebuilt 
    rebuilt = self.static.build()
    if not rebuilt: return False

    self._out.write("Templates [%s] => [%s]\n" % (self.src, self.dst));

    for filepath, info in self.manifest().items():
      if rebuilt > 1 or self._has_changes(filepath, info):
        srcpath = os.path.join(self.src, filepath)
        dstpath = os.path.join(self.dst, filepath)
        self._process_template(srcpath, dstpath)
    # success
    return True


  _BUILD_ATTR_NAME = 'data-build'

  def _process_template(self, src, target):
    """Looks for data-build='...' with these values:
    - remove
    - tr:/path/to/asset
    - compress (for <script> tags)

    Also, replaces all URL occurances with their hashed versions (if found).
    """
    self._out.write("** %s\n" % src)
    # lazy loading
    import codecs

    # read the source template file
    data = codecs.open(src, encoding='utf-8').read()

    # make sure target directory exists
    target_dir = os.path.dirname(target)
    self._ensure_dir(target_dir)

    # map to replace dev asset urls with compiled ones
    urlmap = []
    for path, info in self.static.manifest().items():
      if 'hash' in info:
        url = '/' + path
        repl = self._hashify_path(url, info['hash'])
        urlmap.append((url, repl))

    # remove fragment patterns
    s = '\s*<%(tag)s [^>]*data-build="remove"[^>]*>.*?</%(tag)s>'
    patterns = []
    for tag in ['script', 'a', 'div']:
      patterns.append(re.compile(s % {'tag':tag}, re.DOTALL))
    patterns += [
      # simple pattern for stuff like <img> and <link>
      re.compile(r'\s*<[a-z0-9]+ [^>]*data-build="remove"[^>]/?>'),
      # removes <!-- comments -->
      re.compile(r'\s*<!--.*?-->', re.DOTALL)
    ]

    # do the actual content mangling
    repl = Replacer(data)
    repl.remove(*patterns)
    repl.replace(urlmap)
    repl.transform(re.compile(
      r'\s*<script ([^>]*)data-build="compress"([^>]*)>(.*?)</script>', re.DOTALL),
      3, r'<script\1\2>%s</script>', self._compress_js
    )
    repl.transform(re.compile(
      # at this point tr:/url will be hashified already
      r'(<[a-z0-9]+ [^>]*)(src|href)="[^"]+"([^>]*)data-build="tr:([^"]+)"', re.DOTALL),
      4, r'\1\2="%s"\3', lambda url: url
    )

    # store processed template string
    f = codecs.open(target, mode='w', encoding='utf-8')
    f.write(repl.data)
    f.close()

  def _has_changes(self, filepath, info):
    """
    Returns true if either file doesn't exist or their
    hashes not equal AND mtime of src file is greater than target.
    """
    dstpath = os.path.join(self.dst, filepath)
    if not os.path.exists(dstpath):
      return True

    stat = os.stat(dstpath)
    return info['ts'] > int(stat.st_mtime)

  def _compress_js(self, script):
    if self.compiler_cmd:
      self._out.write(">> %s:\n%s\n" % (' '.join(self.compiler_cmd), script))
      # lazy loading 
      from subprocess import Popen, PIPE

      p = Popen(self.compiler_cmd, stdin=PIPE, stdout=PIPE, stderr=PIPE)
      out, err = p.communicate(script)
      
      if err: self._err.write(err)
      return out.strip()
    else:
      self._err.write(">> Plese, specify --compiler-jar to compress JS\n")


#
# Main entry point for command line
#

def main():
  """Main entry point for command-line usage"""

  parser = argparse.ArgumentParser(
    description='Static assets and HTML templates builder/compiler')
  parser.add_argument('what', choices=['static', 'templates'])
  parser.add_argument('cmd', choices=['manifest', 'check', 'build'])
  parser.add_argument('--static-src', default='assets')
  parser.add_argument('--static-dst', default='.assets-build')
  parser.add_argument('--templates-src', default='templates')
  parser.add_argument('--templates-dst', default='.templates-build')
  parser.add_argument('--ignore', type=re.compile, action='append', default=[])
  parser.add_argument('--compiler-jar')
  args = parser.parse_args()

  ignore = _RE_IGNORE + args.ignore
  
  _static = StaticBuilder(
    args.static_src, args.static_dst, 
    ignore_patterns=ignore, skip_hash=_RE_SKIP_HASH,
    compiler_jar=args.compiler_jar)
  builder = _static

  if args.what not in ['static']:
    builder = TemplatesBuilder(
      args.templates_src, args.templates_dst, 
      _static, ignore_patterns=ignore, compiler_jar=args.compiler_jar)

  meth = 'do_%s' % args.cmd
  getattr(builder, meth)()


if __name__ == '__main__':
  main()
