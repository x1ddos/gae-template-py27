# -*- coding: utf-8 -*-
import re

_re_br = re.compile('(\n|\r|\n\r)+')
_re_href = re.compile(r'(https?://)([a-z0-9/\?#!\$&\'\(\)\*\.\+=]+)')

def simple_format(text):
  """Converts text into HTML replacing \n with <br> 
  and links with <a href=''>...</a> tags
  """
  return _re_href.sub(r'<a href="\1\2" target="_blank" rel="nofollow">\2</a>', _re_br.sub('<br>', unicode(text or '')))
  
