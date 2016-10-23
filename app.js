var express = require('express'), 
	app = express(),
	exec = require('child_process').exec,
	bodyParser = require('body-parser'),
	path = require('path'),
	os = require('os'),
	fs = require('fs-extra'),
	appDir = __dirname,
	appDataDir = path.join(appDir, 'data'),
	appUserProfileDir = path.join(appDataDir, 'userprofile');

// parse application/x-www-form-urlencoded
app.use(bodyParser.urlencoded({ extended: false }));
// parse application/json
app.use(bodyParser.json());

app.get('/', function(req, res){
	res.sendFile(path.join(appDir, 'app-index.html'));
});

app.get('/pandoc/example-form', function(req, res) {
	res.sendFile(path.join(appDir, 'app-example-form.html'));
})

app.get('/pandoc', function(req, res){
	var html = '<!DOCTYPE html><head><meta charset="utf-8"><title>Pandoc</title><html><body>' +
	'<h1>This is the format converter Pandoc, which converts Markdown to different output formats</h1>' +
	'<p>You need to post the following data:</p><ul>' +
	'<li><b>filename</b> (mandatory): the name of the file without an extension</li>' +
	'<li><b>format</b> (mandatory): the format you wish to have - can be currently: pdf, docx, html</li>' +
	'<li><b>markdown</b> (mandatory): the text in markdown format you wish to convert</li>' +
	'<li><b>options</b> (optional): additional pandoc commandline options</li>' +
	'</ul><h2>DEBUG: Your request headers</h2><ul>';
	for (var key in req.headers) {
		if ( req.headers.hasOwnProperty(key) && key !== 'authorization' ) {
			html = html + '<li>' + key + ': ' + req.headers[key] + '</li>';
		}
	}
	html = html + '</ul>' +
	'<h2>DEBUG: Calculated temporary dir name</h2><p>' +
	path.join( appDataDir, ( new Date().toISOString().replace(/:/g,'-') ) ) +
	'</p></body></html>';
	res.send(html);
});

app.post('/pandoc/', function(req, res){
	//http://pandoc.org/README.html#general-options
	//console.log(JSON.stringify(req.headers));
	//console.log(JSON.stringify(req.body));
	var pandoc,
		error = '',
		tempDateString = new Date().toISOString().replace(/:/g,'-'),
		tempDir = path.join( appDataDir, ( tempDateString + '-' + (req.body.id?'-Job-ID-'+req.body.id:'') + req.body.format ) ),
		tempDirSourceFile = path.join( tempDir, 'document.md' ),
		tempDirTargetFile = path.join( tempDir, 'document.' + req.body.format),
		tempDirConvertScript = path.join( tempDir, 'convert.bat'),
		prodConvertScript = path.join( appDataDir, 'prod', 'convert.bat'),
		convertShellCommand = path.join( tempDir, 'convert.bat ' + req.body.format + ( req.body.options ? ' ' + req.body.options : '' ) ),
		execOptions = { cwd:tempDir, env:{ userprofile:appUserProfileDir } };
	
	//write temporary file to convert
	if (!req.body.markdown) {
		res.status(500).send('No Markdown text to convert');
	}
	else if (!/^html|pdf|docx$/.test(req.body.format)) {
		res.status(500).send('Invalid format - available formats are html, pdf, docx.');
	}
	else {
		fs.outputFile(tempDirSourceFile, req.body.markdown, function (err) {
			if (err) {
				res.status(500).send('Unable to write Markdown source to ' + tempDirSourceFile + ': ' + err.message);
			}
			else {
				//read current productive convert script
				fs.readFile(prodConvertScript, 'utf8', function(err, data) {
					if (err) {
						res.status(500).send('Unable to read current productive convert script. ' + err.message);
					}
					else {
						fs.outputFile(tempDirConvertScript, 'rem used shell command: ' + convertShellCommand + '\n' + data, function (err) {
							if (err) {
								res.status(500).send('Unable to write temp convert script. ' + err.message);
							}
							else {
								//execute convert shell command
								console.log(convertShellCommand);
								pandoc = exec(convertShellCommand, execOptions);
								//collect error data, if any
								pandoc.stderr.on('data', function (data) {
									if (data) { error += data; }
								});
								//listen on exit
								pandoc.on('close', function (code) {
									var message, file, stat;
									if (code !== 0) {
										message = 'Pandoc terminated with return code ' + code + ( error ? ': ' : '.');
										if ( error ) { message += error } ;
										res.status(500).send(message);
									}
									else {
										//send file to browser as download
										res.download(tempDirTargetFile, req.body.filename + '.' + req.body.format || tempDateString + '.' + req.body.format, function(err){
											if (err) {
												//FIXME: What to do in case of error here?
												//Handle error, but keep in mind the res may be partially-sent
												//so check res.headersSent
											} 
											else {
												//delete temporary files
												fs.remove(tempDir, function (err) {
													if (err) {return console.error(err) }
												});
											}
										});
									}
								});
							}
						});
					}
				});
			}
		});
	}
}); //finished - welcome to the callback hell ;-)

app.listen(process.env.PORT||3000); //this can be run in IIS with module iisnode - see also https://github.com/tjanczuk/iisnode
