echo off
cls

if [%1]==[] echo Please provide the desired target format as a parameter - example: convert html & goto end

set       format=%1
set filterformat=%1
set       filter=..\..\pandoc_filter\pandocFilterMarkdownReporter.py
set      datadir=..
set       pandoc=c:\og\PortableApps\pandoc\pandoc.exe
set       python=c:\og\PortableApps\python\python-3.5.2.amd64\python.exe
set        latex=c:\og\PortableApps\miktex\miktex\bin\lualatex.exe

rem remove the first parameter (the format)
shift
rem fill var params with remaining parameters
set params=%1
:loop
shift
if [%1]==[] goto afterloop
set params=%params% %1
goto loop
:afterloop

rem ensure the same format names like pandoc - for PDF files the output format is latex!
if %format%==pdf set filterformat=latex

echo generate JSON source...
%pandoc% document.md --from=markdown --to=json --output=document.json %params%

echo apply filter (generate charts from relevant code blocks)...
%python% %filter% %filterformat%

echo generate target document...
if %format%==html %pandoc% document.filtered.json --from=json --to=html --output=document.html --data-dir=%datadir% --self-contained --standalone  %params%
if %format%==docx %pandoc% document.filtered.json --from=json --to=docx --output=document.docx --data-dir=%datadir% %params%
if %format%==pdf  %pandoc% document.filtered.json --from=json --to=latex --output=document.pdf --data-dir=%datadir% --latex-engine=%latex% %params%

:end