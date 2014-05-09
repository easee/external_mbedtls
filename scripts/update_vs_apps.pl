#!/usr/bin/perl

# create individual project files for example programs
# for VS6 and VS2010
#
# Must be run from PolarSSL root or scripts directory.
# Takes no argument.

use warnings;
use strict;
use Digest::MD5 'md5_hex';

my $vs6_dir = "visualc/VS6";
my $vs6_ext = "dsp";
my $vs6_app_tpl_file = "scripts/data_files/vs6-app-template.$vs6_ext";
my $vs6_main_tpl_file = "scripts/data_files/vs6-main-template.$vs6_ext";
my $vs6_main_file = "$vs6_dir/polarssl.$vs6_ext";
my $vs6_wsp_tpl_file = "scripts/data_files/vs6-workspace-template.dsw";
my $vs6_wsp_file = "$vs6_dir/polarssl.dsw";

my $vsx_dir = "visualc/VS2010";
my $vsx_ext = "vcxproj";
my $vsx_app_tpl_file = "scripts/data_files/vs2010-app-template.$vsx_ext";
my $vsx_main_tpl_file = "scripts/data_files/vs2010-main-template.$vsx_ext";
my $vsx_main_file = "$vsx_dir/PolarSSL.$vsx_ext";
my $vsx_sln_tpl_file = "scripts/data_files/vs2010-sln-template.sln";
my $vsx_sln_file = "$vsx_dir/PolarSSL.sln";

my $programs_dir = 'programs';
my $header_dir = 'include/polarssl';
my $source_dir = 'library';

# Need windows line endings!
my $vs6_file_tpl = <<EOT;
# Begin Source File\r
\r
SOURCE=..\\..\\{NAME}\r
# End Source File\r
EOT

my $vs6_wsp_entry_tpl = <<EOT;
###############################################################################\r
\r
Project: "{NAME}"=.\\{NAME}.dsp - Package Owner=<4>\r
\r
Package=<5>\r
{{{\r
}}}\r
\r
Package=<4>\r
{{{\r
    Begin Project Dependency\r
    Project_Dep_Name polarssl\r
    End Project Dependency\r
}}}\r
\r
EOT

my $vsx_hdr_tpl = <<EOT;
    <ClInclude Include="..\\..\\{NAME}" />\r
EOT
my $vsx_src_tpl = <<EOT;
    <ClCompile Include="..\\..\\{NAME}" />\r
EOT

my $vsx_sln_app_entry_tpl = <<EOT;
Project("{8BC9CEB8-8B4A-11D0-8D11-00A0C91BC942}") = "{APPNAME}", "{APPNAME}.vcxproj", "{GUID}"\r
	ProjectSection(ProjectDependencies) = postProject\r
		{46CF2D25-6A36-4189-B59C-E4815388E554} = {46CF2D25-6A36-4189-B59C-E4815388E554}\r
	EndProjectSection\r
EndProject\r
EOT

my $vsx_sln_conf_entry_tpl = <<EOT;
		{GUID}.Debug|Win32.ActiveCfg = Debug|Win32\r
		{GUID}.Debug|Win32.Build.0 = Debug|Win32\r
		{GUID}.Debug|x64.ActiveCfg = Debug|x64\r
		{GUID}.Debug|x64.Build.0 = Debug|x64\r
		{GUID}.Release|Win32.ActiveCfg = Release|Win32\r
		{GUID}.Release|Win32.Build.0 = Release|Win32\r
		{GUID}.Release|x64.ActiveCfg = Release|x64\r
		{GUID}.Release|x64.Build.0 = Release|x64\r
EOT

exit( main() );

sub check_dirs {
    return -d $vs6_dir
        && -d $vsx_dir
        && -d $header_dir
        && -d $source_dir
        && -d $programs_dir;
}

sub slurp_file {
    my ($filename) = @_;

    local $/ = undef;
    open my $fh, '<', $filename or die "Could not read $filename\n";
    my $content = <$fh>;
    close $fh;

    return $content;
}

sub gen_app_guid {
    my ($path) = @_;

    my $guid = md5_hex( "PolarSSL:$path" );
    $guid =~ s/(.{8})(.{4})(.{4})(.{4})(.{12})/\U{$1-$2-$3-$4-$5}/;

    return $guid;
}

sub gen_app {
    my ($path, $template, $dir, $ext) = @_;

    my $guid = gen_app_guid( $path );
    $path =~ s!/!\\!g;
    (my $appname = $path) =~ s/.*\\//;

    my $content = $template;
    $content =~ s/<PATHNAME>/$path/g;
    $content =~ s/<APPNAME>/$appname/g;
    $content =~ s/<GUID>/$guid/g;

    open my $app_fh, '>', "$dir/$appname.$ext";
    print $app_fh $content;
    close $app_fh;
}

sub get_app_list {
    my $app_list = `cd $programs_dir && make list`;
    die "make list failed: $!\n" if $?;

    return split /\s+/, $app_list;
}

sub gen_app_files {
    my @app_list = @_;

    my $vs6_tpl = slurp_file( $vs6_app_tpl_file );
    my $vsx_tpl = slurp_file( $vsx_app_tpl_file );

    for my $app ( @app_list ) {
        gen_app( $app, $vs6_tpl, $vs6_dir, $vs6_ext );
        gen_app( $app, $vsx_tpl, $vsx_dir, $vsx_ext );
    }
}

sub gen_entry_list {
    my ($tpl, @names) = @_;

    my $entries;
    for my $name (@names) {
        (my $entry = $tpl) =~ s/{NAME}/$name/g;
        $entries .= $entry;
    }

    return $entries;
}

sub gen_main_file {
    my ($headers, $sources, $hdr_tpl, $src_tpl, $main_tpl, $main_out) = @_;

    my $header_entries = gen_entry_list( $hdr_tpl, @$headers );
    my $source_entries = gen_entry_list( $src_tpl, @$sources );

    my $out = slurp_file( $main_tpl );
    $out =~ s/SOURCE_ENTRIES\r\n/$source_entries/m;
    $out =~ s/HEADER_ENTRIES\r\n/$header_entries/m;

    open my $fh, '>', $main_out or die;
    print $fh $out;
    close $fh;
}

sub gen_vs6_workspace {
    my (@app_names) = @_;

    map { s!.*/!! } @app_names;
    my $entries = gen_entry_list( $vs6_wsp_entry_tpl, @app_names );

    my $out = slurp_file( $vs6_wsp_tpl_file );
    $out =~ s/APP_ENTRIES\r\n/$entries/m;

    open my $fh, '>', $vs6_wsp_file or die;
    print $fh $out;
    close $fh;
}

sub gen_vsx_solution {
    my (@app_names) = @_;

    my ($app_entries, $conf_entries);
    for my $path (@app_names) {
        my $guid = gen_app_guid( $path );
        (my $appname = $path) =~ s!.*/!!;

        my $app_entry = $vsx_sln_app_entry_tpl;
        $app_entry =~ s/{APPNAME}/$appname/g;
        $app_entry =~ s/{GUID}/$guid/g;

        $app_entries .= $app_entry;

        my $conf_entry = $vsx_sln_conf_entry_tpl;
        $conf_entry =~ s/{GUID}/$guid/g;

        $conf_entries .= $conf_entry;
    }

    my $out = slurp_file( $vsx_sln_tpl_file );
    $out =~ s/APP_ENTRIES\r\n/$app_entries/m;
    $out =~ s/CONF_ENTRIES\r\n/$conf_entries/m;

    open my $fh, '>', $vsx_sln_file or die;
    print $fh $out;
    close $fh;
}

sub main {
    if( ! check_dirs() ) {
        chdir '..' or die;
        check_dirs or die "Must but run from PolarSSL root or scripts dir\n";
    }

    my @app_list = get_app_list();
    my @headers = <$header_dir/*.h>;
    my @sources = <$source_dir/*.c>;
    map { s!/!\\!g } @headers;
    map { s!/!\\!g } @sources;

    print "Generating apps files... ";
    gen_app_files( @app_list );
    print "done.\n";

    print "Generating main files... ";
    gen_main_file( \@headers, \@sources,
                   $vs6_file_tpl, $vs6_file_tpl,
                   $vs6_main_tpl_file, $vs6_main_file );
    gen_main_file( \@headers, \@sources,
                   $vsx_hdr_tpl, $vsx_src_tpl,
                   $vsx_main_tpl_file, $vsx_main_file );
    print "done.\n";

    print "Generating VS6 workspace file... ";
    gen_vs6_workspace( @app_list );
    print "done.\n";

    print "Generating VS2010 solution file... ";
    gen_vsx_solution( @app_list );
    print "done.\n";

    return 0;
}
