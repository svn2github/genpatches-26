#!/usr/bin/perl
# Copyright 2000-2004 Gentoo Foundation; Distributed under the GPL v2

use gentoo_sources_web;

$kerneldir = shift;
$outfile = shift;

$kerneldir .= '/';

opendir(DIR, $kerneldir);
@files = grep(/\.patch$/,readdir(DIR));
closedir(DIR);

open(README, "< " . $kerneldir . '/0000_README');
@readme = <README>;
close(README);

open(FD, '> '.$outfile);
html_header *FD;

print FD '<h1>Patch List</h1>';
print FD '<table border="1">';
print FD '<tr>';
print FD '<th>Patch</th>';
print FD '<th>Header</th>';
print FD '</tr>';

foreach $file (sort @files) {
	$path = $kerneldir.$file;
	print FD '<tr>';
	print FD '<td valign="top"><b>'.substr($file, 0, -6).'</b><br />'.html_urlify(readme_get_from($file, @readme)).'<br />'.html_escape(readme_get_description($file, @readme)).'</td>';
	print FD '<td>'.nl2br(html_escape(get_patch_header($path))).'</td>';
	print FD '</tr>';
}

print FD '</table>';
html_footer *FD;
close(FD);