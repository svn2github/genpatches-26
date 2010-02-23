# Copyright 2000-2009 Gentoo Foundation; Distributed under the GPL v2

# Detect which svn server and username to use
$subversion_scheme = `svn info 2>/dev/null | head -n 2 | tail -n 1`;
$subversion_uri = $subversion_scheme;
chomp $subversion_uri;
$subversion_scheme =~ s|^URL: ([a-z][a-z0-9+-.]*)://.*|\1|s;

if ($subversion_scheme == "svn+ssh") {
	$trimmed = substr($subversion_uri, 15);
	if ($trimmed =~ m/^([a-zA-Z]+)@/) {
		$subversion_midpart = "$1\@svn.gentoo.org/var/svnroot";
	} else {
		# couldn't detect username
		$subversion_midpart = 'svn.gentoo.org/var/svnroot';
	}
} else {
	$subversion_midpart = 'anonsvn.gentoo.org';
}
$subversion_root = $subversion_scheme.'://'.$subversion_midpart.'/linux-patches/genpatches-2.6';

$webscript_path = &Cwd::cwd();
$output_path = $webscript_path.'/output';

$website_base = 'http://dev.gentoo.org/~mpagano/genpatches';

$ebuild_base = '/usr/local/gentoo-x86'; # /usr/portage
@kernels = ('sys-kernel/gentoo-sources', 'sys-kernel/hardened-sources', 'sys-kernel/xen-sources', 'sys-kernel/rsbac-sources', 'sys-kernel/tuxonice-sources', 'sys-kernel/usermode-sources', 'sys-kernel/vserver-sources');

sub html_header {
	local *FD = shift;
	my $title = shift;
	$title = 'genpatches-2.6 infopage' if !$title;
	
	print FD '<html>';
	print FD '<head>';
	print FD '<title>'.$title.'</title>';
	print FD '<link rel="stylesheet" href="style.css" />';
	print FD '</head>';
	print FD '<body>';
	print FD '<div class="menu">';
	print FD '<span class="menu"><a href="index.htm">Home</a></span>';
	print FD '<span class="menu"><a href="about.htm">About</a></span>';
	print FD '<span class="menu"><a href="faq.htm">FAQ</a></span>';
	print FD '<span class="menu"><a href="releases.htm">Releases</a></span>';
	print FD '<span class="menu"><a href="bugs.htm">Bugs</a></span>';
	print FD '<span class="menu"><a href="issues.htm">Issues</a></span>';
	print FD '</div>'
}

sub html_footer {
	local *FD = shift;
	my $date = `date`;
	my $user = `whoami`;

	print FD '<hr /><div align="right">Automatically generated: '.$date.' by '.$user.'</div>';
	print FD '</body>';
	print FD '</html>';
}

# From CGI::MxScreen
sub html_escape {
	my $t = shift;
	$t =~ s/&/&amp;/g;
	$t =~ s/\"/&quot;/g;
	$t =~ s/>/&gt;/g;
	$t =~ s/</&lt;/g;
	return $t;
}

# Shamelessly stolen from irc2html
# irc2html.pl --- converts raw IRC logs to a readable HTML table-ized form.
# Copyright © 1998, 1999, 2000, 2002, 2003, 2004 Jamie Zawinski <jwz@jwz.org>
sub html_urlify {
	my $str = shift;
	my $url_re = q{\b(s?https?|ftp|file|gopher|s?news|telnet|mailbox):} .
		q{(//[-A-Z0-9_.]+:\d*)?} .
		q{[-A-Z0-9_=?\#\$\@~\`%&*+|\/.,;\240]+};
	$str =~ s@($url_re)@<A HREF="$1">$1</A>@gi;
	return $str;
}

sub issues_get_questions {
	my $file = shift;
	my $out;
	local *ISSUES;
	
	open(ISSUES, '< '.$file);
	foreach (<ISSUES>) {
		chomp;
		last if $_ eq '--';
		$out .= $_ . "\n";
	}
	close(ISSUES);
	return $out;
}

sub issues_get_answers {
	my $file = shift;
	my ($out, $ddcount);
	local *ISSUES;
	$ddcount = 0;
	
	open(ISSUES, '< '.$file);
	foreach (<ISSUES>) {
		chomp;
		if ($_ eq '--') {
			$ddcount++;
			next;
		}
		$out .= $_ . "\n" if $ddcount == 1;
	}
	close(ISSUES);
	return $out;
}

sub issues_get_info {
	my $file = shift;
	my ($out, $ddcount);
	local *ISSUES;
	$ddcount = 0;
	
	open(ISSUES, '< '.$file);
	foreach (<ISSUES>) {
		chomp;
		if ($_ eq '--') {
			$ddcount++;
			next;
		}
		if ($ddcount == 2) {
			if ($_ =~ /^#([0-9]+)$/) {
				$out .= '<a href="http://bugs.gentoo.org/'.$1.'">Bug '.$1.'</a>' . "\n";
			} elsif ($_ =~ /^[0-9]{8}/) {
				$out .= "Date: $_\n";
			} elsif ($_ =~ /^[0-9]\.[0-9]\.[0-9]$/) {
				$out .= "Kernel: $_\n";
			}
		}
	}
	close(ISSUES);
	return $out;
}

sub nl2br {
	my $content = shift;
	$content =~ s/\n/<br \/>/g;
	return $content;
}

sub include_content {
	local *FD = shift;
	my $page = shift;
	local *CONTENT;

	open(CONTENT, '< '.$webscript_path.'/content/'.$page.'.htm');
	print FD $_ foreach <CONTENT>;
	close(CONTENT);
}

sub include_generated {
	local *FD = shift;
	my $page = shift;
	local *CONTENT;

	open(CONTENT, '< '.$webscript_path.'/generated/'.$page);
	print FD $_ foreach <CONTENT>;
	close(CONTENT);
}

sub include_faq {
	local *FD = shift; 
	my $page = shift;
	local *CONTENT;
	my $i;
	
	open(CONTENT, '< '.$webscript_path.'/content/faq/'.$page);
	$i = 0;
	foreach (<CONTENT>) {
		if ($i++ == 0) {
			print FD '<b>Q. '.$_.'</b><br />';
		} else {
			print FD $_ . '<br />';
		}
	}
	close(CONTENT);
	print FD '<br /><br />';
}

sub _get_patch_list {
	my $tag = shift;
	my $cmd = 'svn cat '.$subversion_root.'/tags/'.$tag.'/0000_README';
	my @readme_lines = `$cmd`;
	my @patches;
	my $count = -1;

	foreach (@readme_lines) {
		chomp;
		
		if (/^[Pp]atch:[ \t]+(.*)$/) {
			$count++;
			$patches[$count]{'patch'} = $1;
		}

		if (/^[Ff]rom:[ \t]+(.*)$/) {
			$patches[$count]{'from'} = $1;
		}

		if (/^[Dd]esc:[ \t]+(.*)$/) {
			$patches[$count]{'desc'} = $1;
		}
	}

	return @patches;
}

sub _parse_log {
	my $tag = shift;
	my $lastrev = shift;
	my (@commits, $state, $rev);
	my $cmd = 'svn log -v -r '.$lastrev.':HEAD '.$subversion_root.'/tags/'.$tag;
	my @loglines = `$cmd`;

	foreach (@loglines) {
		if (/^-+$/) {
			$state = '';
			next;
		}

		if ($state eq 'wantpaths') {
			if (/^\s+([A-Z]) \/genpatches-2\.6\/trunk\/[\d\.]+\/([^\s]+)/) {
				push (@{$commits[$rev]{"action$1"}}, $2) if $2 != "0000_README";
			} elsif (/^$/) {
				$state = 'wantlog';
			}
			next;
		}

		if ($state eq 'wantlog') {
			$commits[$rev]{'logmsg'} .= "\n$_";
			next;
		}

		if (/^r(\d+) \| (\w+) \|/) {
			$state = 'wantpaths';
			$rev = $1;
			$commits[$rev]{'rev'} = $rev;
			$commits[$rev]{'author'} = $2;
			next;
		}
	}

	return @commits;
}

sub release_is_generated {
	my $tag = shift;
	return -e $webscript_path.'/generated/'.$tag.'-patches.htm' &&
		-e $webscript_path.'/generated/'.$tag.'-info.htm';
}

sub _get_genpatches_kernels {
	my (%gp_kernels, $kernel);

	foreach $kernel (@kernels) {
		$kernel =~ m/^([a-z-]+)\/([a-z0-9-]+)$/;
		my $cat = $1;
		my $pkg = $2;
		$cmd = 'egrep "^(K_GENPATCHES_VER|K_WANT_GENPATCHES)" '.$ebuild_base.'/'.$kernel.'/*.ebuild';
		my @out = `$cmd`;

		foreach (@out) {
			chomp;
			my $res = substr($_, length($ebuild_base) + length($kernel) + 2);
			$res =~ m/^$pkg-([\d\w\.-]+)\.ebuild:(.*)$/;
			my $ver = $1;
			my $var = $2;
			my $ebuild = $pkg.'-'.$ver;
			$ver =~ m/^(2\.6\.\d+)/;
			my $orig_ver = $1;

			if ($var =~ /^K_WANT_GENPATCHES="(.*)"$/) {
				$gp_kernels{$ebuild}{'pkg'} = $pkg;
				$gp_kernels{$ebuild}{'ver'} = $ver;
				$gp_kernels{$ebuild}{'wanted'} = $1;
			}
			if ($var =~ /^K_GENPATCHES_VER="(\d+)"$/) {
				$gp_kernels{$ebuild}{'gprev'} = $orig_ver .'-'. $1;
			}
		}
	}

	return %gp_kernels;
}


1;

