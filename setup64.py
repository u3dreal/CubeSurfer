from distutils.core import setup
from distutils.extension import Extension
from Cython.Distutils import build_ext
import Cython.Compiler.Options

Cython.Compiler.Options.annotate = True

from sys import platform
if platform == "linux" or platform == "linux2":
    ext_modules = [Extension("mciso", ["mciso.pyx"],
    extra_compile_args=['-O2', '-fopenmp', '-ffast-math'],
    extra_link_args=['-fopenmp'])]
elif platform == "darwin":
    ext_modules = [Extension("mciso", ['mciso' + '.pyx'],
    extra_compile_args=['-march=x86-64', '-msse4.2', '-O3', '-ffast-math', '-fopenmp'],
    extra_link_args=['-fopenmp', '-static', '-lm'] )]
elif platform == "win32":
    ext_modules = [Extension("mciso", ["mciso.pyx"],
    extra_compile_args=['/O2', '/openmp', '/fp:fast'])]

setup(
  name = 'CubeSurfer core script',
  cmdclass = {'build_ext': build_ext},
  ext_modules = ext_modules
)
