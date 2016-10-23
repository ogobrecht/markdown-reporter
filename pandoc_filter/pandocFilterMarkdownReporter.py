#!/usr/bin/env python
import hashlib
import os
import sys
from io import StringIO
from pandocfiltersFileBased import toJSONFilter, Para, Image, LineBreak, Str
from matplotlib import rcParams
rcParams.update({'figure.autolayout': True}) #http://stackoverflow.com/questions/6774086/why-is-my-xlabel-cut-off-in-my-matplotlib-plot
import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns
sns.set(style='ticks', palette='Set2')

def sha1(x):
	return hashlib.sha1(x.encode(sys.getfilesystemencoding())).hexdigest()

def chart(key, value, format, meta):
	if key == 'CodeBlock':
		[[ident, classes, keyvals], code] = value
		if all (key in classes for key in ('sql','chart')):
			filename = sha1(code)
			if format == 'html':
				filetype = 'svg'
			elif format == 'latex':
				filetype = 'pdf'
			else:
				filetype = 'png'
			caption = ''
			for i, val in enumerate(keyvals):
				if val[0] == 'caption':
					caption = val[1]

			#create pie chart file
			if 'pie' in classes:
				file = filename + 'pie.' + filetype
				df = pd.read_csv(StringIO( code ), index_col=0)
				df.plot.pie(y=0, figsize=(6, 6), autopct='%.1f', legend=False)
				sns.despine()
				plt.savefig(file)
				plt.close()
				if caption != '': # floating image (figure environment) in pdf, see also http://pandoc.org/MANUAL.html#extension-implicit_figures
					return Para([Image(['', [], []], [Str(caption)], [file, 'fig:'])])
				else: # we forcing here an inline image with the help of a linebreak and a space character
					return Para([Image(['', [], []], [Str('No caption available')], [file, '']), LineBreak(), Str(' ')])

			#create bar chart file
			elif 'bar' in classes:
				file = filename + 'bar.' + filetype
				df = pd.read_csv(StringIO( code ), index_col=0)
				df.plot.bar(subplots=False, figsize=(9, 6), legend=True)
				sns.despine()
				plt.savefig(file)
				plt.close()
				if caption != '': # floating image (figure environment) in pdf, see also http://pandoc.org/MANUAL.html#extension-implicit_figures
					return Para([Image(['', [], []], [Str(caption)], [file, 'fig:'])])
				else: # we forcing here an inline image with the help of a linebreak and a space character
					return Para([Image(['', [], []], [Str('No caption available')], [file, '']), LineBreak(), Str(' ')])

			#create horizontal bar chart file
			elif 'barh' in classes:
				file = filename + 'barh.' + filetype
				df = pd.read_csv(StringIO( code ), index_col=0)
				df.plot.barh(subplots=False, figsize=(9, 6), legend=True)
				sns.despine()
				plt.savefig(file)
				plt.close()
				if caption != '': # floating image (figure environment) in pdf, see also http://pandoc.org/MANUAL.html#extension-implicit_figures
					return Para([Image(['', [], []], [Str(caption)], [file, 'fig:'])])
				else: # we forcing here an inline image with the help of a linebreak and a space character
					return Para([Image(['', [], []], [Str('No caption available')], [file, '']), LineBreak(), Str(' ')])

if __name__ == '__main__':
	toJSONFilter(chart)
