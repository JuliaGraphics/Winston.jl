# Julia domain for Sphinx
# http://sphinx.pocoo.org/domains.html

import docutils.nodes
import hashlib
import os, os.path
import re
import sphinx.domains.python
from sphinx.util.osutil import ensuredir
import tempfile

try:
    from docutils.parsers.rst.directives.body import CodeBlock
    oldstyle_code_block = False
except:
    from sphinx.directives.code import CodeBlock
    oldstyle_code_block = True

sphinx.domains.python.py_sig_re = re.compile(
    r'''^ ([\w.]+\.)?            # class name(s)
          ([^\s(]+)  \s*         # thing name
          (?: \((.*)\)           # optional: arguments
           (?:\s* -> \s* (.*))?  #           return annotation
          )? $                   # and nothing more
          ''', re.VERBOSE | re.UNICODE)

class JuliaDomain(sphinx.domains.python.PythonDomain):
    """Julia language domain."""
    name = 'jl'
    label = 'Julia'

def write_tmpfile(content):
    f = tempfile.NamedTemporaryFile(delete=False)
    f.write(content)
    f.close()
    return f.name

def run_julia_script(script):
    cmd = "julia " + write_tmpfile(script)
    return os.system(cmd)

class winston(docutils.nodes.Inline, docutils.nodes.TextElement):
    pass

def html_visit_winston(self, node):
    script = node['script']
    sha1 = hashlib.sha1(script).hexdigest()
    fn = "winston/%s.png" % sha1

    if 'READTHEDOCS' in os.environ:
        url = "http://d1qchgnwtps1zh.cloudfront.net/" + fn
    else:
        url = os.path.join(self.builder.imgpath, fn)
        fn = os.path.join(self.builder.outdir, '_images', fn)
        if not os.path.isfile(fn):
            var = "Winston._pwinston"
            ensuredir(os.path.dirname(fn))
            script = 'using Winston\n%s\nfile(%s,"%s")' % (script,var,fn)
            try:
                run_julia_script(script)
            except:
                pass

    self.body.append('<img src="' + url + '"/>')
    raise docutils.nodes.SkipNode

class WinstonDirective(CodeBlock):

    required_arguments = 0

    def run(self):
	if oldstyle_code_block and len(self.arguments) == 0:
	    self.arguments.append('julia')

        node = winston()
        node['script'] = '\n'.join(self.content)

        nodes = super(WinstonDirective,self).run()
        return nodes + [node]

JuliaDomain.directives.update({
    'type'      : JuliaDomain.directives['class'],
})

def setup(app):
    app.add_domain(JuliaDomain)
    app.add_directive('winston', WinstonDirective)
    app.add_node(winston,
            html=(html_visit_winston,None))

