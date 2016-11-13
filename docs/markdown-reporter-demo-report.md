---
title: Reporting Differently, Thank Markdown - Demo Report
author: Ottmar Gobrecht
date: 2016-11-13
lang: en
papersize: A4
geometry: top=2cm, bottom=2cm, left=2cm, right=2cm
fontsize: 11pt
documentclass: article
classoption: twocolumn
links-as-notes: true
---

*This is a demo report to show the current possible chart types with [Markdown Reporter](https://github.com/ogobrecht/markdown-reporter). We use the population development of New York, Rio and Tokio as example data.*

The line chart and the area charts have captions. The prefix "Figure x:" is automatically placed by the LaTeX engine when you define a figure. Since you use Markdown you do not define the figures by yourself – this is done automatically by [Pandoc](http://pandoc.org/MANUAL.html#extension-implicit_figures), when you place an image link in your text – and the charts are in fact images. LaTeX is using so called [Floats](https://en.wikibooks.org/wiki/LaTeX/Floats,_Figures_and_Captions) to place figures in the text stream. The thing is, that depending on the size of a figure, you have no guarantee, that a figure is placed where you put your links or code blocks for the charts – LaTeX is using the best place in respect of the figure size and the typographic layout.

You can define a caption in your code block like so: `{.sql .chart .line caption="Line Chart"}`

``` {.sql .chart .line caption="Line Chart"}
Population Development,New York,Rio,Tokio
1940,7454995,1759277,6778804
1950,7891957,2375280,5385071
1960,7781984,3300431,8310027
1970,7895563,4251918,8840942
1980,7071639,5090723,8351893
1990,7322564,5480768,8163573
2000,8008278,5857904,8134688
2010,8175133,6320446,8980768
```

The area chart is per default stacked in Python matplotlib. To be consistent with the chart key words, Markdown Reporter uses always the base keyword for an unstacked chart (area, bar, barh) and the postfix _stacked for an stacked chart (area_stacked, bar_stacked, barh_stacked).

``` {.sql .chart .area caption="Area Chart"}
Population Development,New York,Rio,Tokio
1940,7454995,1759277,6778804
1950,7891957,2375280,5385071
1960,7781984,3300431,8310027
1970,7895563,4251918,8840942
1980,7071639,5090723,8351893
1990,7322564,5480768,8163573
2000,8008278,5857904,8134688
2010,8175133,6320446,8980768
```

``` {.sql .chart .area_stacked caption="Area Chart Stacked"}
Population Development,New York,Rio,Tokio
1940,7454995,1759277,6778804
1950,7891957,2375280,5385071
1960,7781984,3300431,8310027
1970,7895563,4251918,8840942
1980,7071639,5090723,8351893
1990,7322564,5480768,8163573
2000,8008278,5857904,8134688
2010,8175133,6320446,8980768
```

In LaTeX a new page can be forced with the command `\newpage`. Pandoc is accepting this command and passes it to output formats who understand this. We use it now :-)

\newpage

Markdown Reporter has by default these options set for numeric value formatting: 

- `numlang=en`
- `numformat=%.0f`
- `numgrouping=true`

You can of course overwrite these options. The `numformat` is a [Python format mask](https://pyformat.info/#number). 

If you need to format your date values then you can use [Pythons date and time format mask](http://strftime.org/) like `dateformat="%Y-%m-%d"` for a ISO date. The default in Markdown Reporter is `dateformat="%Y"`.


``` {.sql .chart .bar}
Population Development,New York,Rio,Tokio
1940,7454995,1759277,6778804
1950,7891957,2375280,5385071
1960,7781984,3300431,8310027
1970,7895563,4251918,8840942
1980,7071639,5090723,8351893
1990,7322564,5480768,8163573
2000,8008278,5857904,8134688
2010,8175133,6320446,8980768
```

We deliver an extra y label and values in millions for the stacked bar chart: `ylabel="Inhabitants (million)"`.

``` {.sql .chart .bar_stacked ylabel="Inhabitants (million)"}
Population Development,New York,Rio,Tokio
1940,7.454995,1.759277,6.778804
1950,7.891957,2.375280,5.385071
1960,7.781984,3.300431,8.310027
1970,7.895563,4.251918,8.840942
1980,7.071639,5.090723,8.351893
1990,7.322564,5.480768,8.163573
2000,8.008278,5.857904,8.134688
2010,8.175133,6.320446,8.980768
```

``` {.sql .chart .barh}
Population Development,New York,Rio,Tokio
1940,7454995,1759277,6778804
1950,7891957,2375280,5385071
1960,7781984,3300431,8310027
1970,7895563,4251918,8840942
1980,7071639,5090723,8351893
1990,7322564,5480768,8163573
2000,8008278,5857904,8134688
2010,8175133,6320446,8980768
```

``` {.sql .chart .barh_stacked xlabel="Inhabitants (million)"}
Population Development,New York,Rio,Tokio
1940,7.454995,1.759277,6.778804
1950,7.891957,2.375280,5.385071
1960,7.781984,3.300431,8.310027
1970,7.895563,4.251918,8.840942
1980,7.071639,5.090723,8.351893
1990,7.322564,5.480768,8.163573
2000,8.008278,5.857904,8.134688
2010,8.175133,6.320446,8.980768
```

Another inline usage of `\newpage` here :-) \newpage

The special thing on an pie chart is, that you have to deliver the data in a different format – you transpose it from a vertical into a horizontal representation. Pandas has also some [possibilities](http://pandas.pydata.org/pandas-docs/stable/reshaping.html) to reshape our data – but since we focus here on easy, generic chart generation this is no option for us. On a pie chart you can set the option `y` to define which column in your data should be used for the pie chart - we use here `y=0` (the default, if you omit this option) for the first (1940) and `y=1` (2010) for the second pie chart.

Pie chart data:

	Population Development,1940,2010
	New York,7454995,8175133
	Rio,1759277,6320446
	Tokio,6778804,8980768

All other charts data:	
	
	Population Development,New York,Rio,Tokio
	1940,7454995,1759277,6778804
	1950,7891957,2375280,5385071
	1960,7781984,3300431,8310027
	1970,7895563,4251918,8840942
	1980,7071639,5090723,8351893
	1990,7322564,5480768,8163573
	2000,8008278,5857904,8134688
	2010,8175133,6320446,8980768
	

``` {.sql .chart .pie y=0 autopct=%.0f%% title="Population Distribution 1940 (in percent)"}
Population Development,1940,2010
New York,7454995,8175133
Rio,1759277,6320446
Tokio,6778804,8980768
```	
	
``` {.sql .chart .pie y=1 autopct=%.0f%% title="Population Distribution 2010 (in percent)"}
Population Development,1940,2010
New York,7454995,8175133
Rio,1759277,6320446
Tokio,6778804,8980768
```

On the pie chart we use also the title attribute, since this chart type has no axes to place our index header: `title="Population Distribution (in percent)"`. Additionally we set the format mask for the percent values, which are calculated by matplotlib: `autopct=%.0f%%`. This is a [Python format mask](https://pyformat.info/#number) and Markdown Reporter uses per default `autopct=%.1f%%`.