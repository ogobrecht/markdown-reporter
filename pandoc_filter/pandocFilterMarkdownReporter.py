#!/usr/bin/env python
import os
import sys
import datetime
import hashlib
import locale
import re
from io import StringIO
from pandocfiltersFileBased import toJSONFilter, Para, Image, LineBreak, Str, RawBlock
from matplotlib import rcParams
rcParams.update({'figure.autolayout': True}) # http://stackoverflow.com/questions/6774086/why-is-my-xlabel-cut-off-in-my-matplotlib-plot
from matplotlib.ticker import FuncFormatter
import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns
sns.set(style='ticks', palette='Set2') # https://github.com/olgabot/prettyplotlib#announcement

def timestamp():
	return datetime.datetime.now().strftime("%Y%m%d.%H%M%S.%f.")
	
def parseBool(x):
	if re.search(r"^(1|y|yes|true)$", x, flags=re.IGNORECASE):
		return True
	elif re.search(r"^(0|n|no|false)$", x, flags=re.IGNORECASE):
		return False
	else:
		return False

def chart(key, value, format, meta):
	# only work on codeblocks
	if key == 'CodeBlock':
		[[ident, classes, keyvals], code] = value
		# charts only, if code block attributes has class sql and chart - example: ```{.sql .chart .line}
		if all (key in classes for key in ('sql','chart')):
			# define chart type
			charttype = ''
			for key in classes:
				if key in ('line','area','area_stacked','bar','bar_stacked','barh','barh_stacked','pie'):
					charttype = key
			if charttype != '':
				# define file format
				if format == 'html':
					filetype = 'svg'
				elif format == 'latex':
					filetype = 'pdf'
				else:
					filetype = 'png'
				# define filename
				filename = timestamp() + charttype + '.' + filetype
				# define default height and width in px and usage of legend
				height = 576 # 6 inch, 96 dpi
				if charttype == 'pie':
					width = 576 
					legend = False
				else:
					width = 864 # 9 inch, 96dpi
					legend = True
				# set other default values
				caption = ''
				title = ''
				xlabel = ''
				ylabel = ''
				if charttype == 'pie':
					dateformat = ''
				else:
					dateformat = '%Y'
				numlang = 'en'
				numformat = '%.0f'
				numgrouping = True
				autopct = '%.1f%%' # for pie chart only
				y = 0              # for pie chart only
				# set user options
				for i, val in enumerate(keyvals):
					if val[0] == 'height':
						height = val[1]
					elif val[0] == 'width':
						width = val[1]
					elif val[0] == 'legend':
						legend = val[1]
					elif val[0] == 'caption':
						caption = val[1]
					elif val[0] == 'title':
						title = val[1]
					elif val[0] == 'xlabel':
						xlabel = val[1]
					elif val[0] == 'ylabel':
						ylabel = val[1]
					elif val[0] == 'dateformat' and charttype != 'pie':
						dateformat = val[1]
					elif val[0] == 'numlang':
						numlang = val[1]
					elif val[0] == 'numformat':
						numformat = val[1]
					elif val[0] == 'numgrouping':
						numgrouping = parseBool(val[1])
					elif val[0] == 'autopct':
						autopct = val[1]
					elif val[0] == 'y':
						y = int(val[1])
				# read csv data from code block
				df = pd.read_csv(StringIO( code ), index_col=0, parse_dates=True)
				# create chart
				if charttype == 'line':
					ax = df.plot.line(subplots=False, figsize=(width/96, height/96), legend=legend) # size must be given in inches, default is 96 dpi
				elif charttype == 'area':
					ax = df.plot.area(subplots=False, figsize=(width/96, height/96), legend=legend, stacked=False)
				elif charttype == 'area_stacked':
					ax = df.plot.area(subplots=False, figsize=(width/96, height/96), legend=legend, stacked=True) 
				elif charttype == 'bar':
					ax = df.plot.bar(subplots=False, figsize=(width/96, height/96), legend=legend, stacked=False)
				elif charttype == 'bar_stacked':
					ax = df.plot.bar(subplots=False, figsize=(width/96, height/96), legend=legend, stacked=True) 
				elif charttype == 'barh':
					ax = df.plot.barh(subplots=False, figsize=(width/96, height/96), legend=legend, stacked=False)
				elif charttype == 'barh_stacked':
					ax = df.plot.barh(subplots=False, figsize=(width/96, height/96), legend=legend, stacked=True) 
				elif charttype == 'pie':
					ax = df.plot.pie(subplots=False, figsize=(width/96, height/96), legend=legend, y=y, autopct=autopct)
				# set title and axis labels
				if title != '':
					ax.set_title(title)
				if xlabel != '':
					ax.set_xlabel(xlabel)
				if ylabel != '':
					ax.set_ylabel(ylabel)
				# set locale for numeric values 
				locale.setlocale(locale.LC_NUMERIC, numlang)
				# tick labels: deactivate scientific notation and format numeric and date values
				if charttype in ('barh','barh_stacked'):
					ax.xaxis.get_major_formatter().set_scientific(False)
					ax.xaxis.set_major_formatter(FuncFormatter(lambda val, pos: locale.format(numformat, val, grouping=numgrouping)))
					if dateformat != '':
						ax.set_yticklabels([dt.strftime(dateformat) for dt in df.index.to_pydatetime()])					
				else:
					ax.yaxis.get_major_formatter().set_scientific(False)
					ax.yaxis.set_major_formatter(FuncFormatter(lambda val, pos: locale.format(numformat, val, grouping=numgrouping)))
					if dateformat != '':
						ax.set_xticklabels([dt.strftime(dateformat) for dt in df.index.to_pydatetime()])					
				# clean up chart with seaborn despine method
				sns.despine()
				# save chart
				plt.savefig(filename)
				plt.close()
				# return image to Pandoc for the code block :-)
				if caption != '': # floating image (figure environment) in pdf, see also http://pandoc.org/MANUAL.html#extension-implicit_figures
					return (
						[
						Para([
						# we deliver styles for the image, so that in case of HTML output Internet Explorer 9-11 is able to resize correctly
						Image(['', [], [['style','width:' + str(width) + 'px; max-width:100%']]], [Str(caption)], [filename, 'fig:'])
						]),
						# styles for the caption, so that we can distinguish between normal text and a caption
						RawBlock("html","<style>.caption{margin:0.3em 0 1.7em 25px;}</style>")
						]
						)
				else: # we forcing here an inline image with the help of a linebreak and a space character
					return (  
						Para([
						Image(['', [], [['style','width:' + str(width) + 'px; max-width:100%']]], [Str('No caption available')], [filename, '']),
						LineBreak(),
						Str(' ')
						])
						)

if __name__ == '__main__':
	toJSONFilter(chart)