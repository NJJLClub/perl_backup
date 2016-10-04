@echo off
perl -w -x -S %0 %1 %2 %3
goto endofperl
#!/usr/bin/perl -w
#
use strict;
use warnings;
#use Cwd;
use English;
use Getopt::Long; 
use File::Basename qw(fileparse);  # for filename parsing
use File::Path qw(make_path remove_tree);
use File::Copy;
#use Time::HiRes;
use POSIX;
#use Tkx;
#Tkx::package_require("Tktable");
#Tkx::package_require("tooltip");
#Tkx::namespace_import("::tooltip::tooltip");

my %Goptions;

my $USERPROFILE = $ENV{'USERPROFILE'};
my $USERNAME = getlogin() || getpwuid($<) || $ENV{USER} ;
my ($PROGRAM_EXE, $PROGRAM_PATH, $tmpsuffix) = fileparse( $PROGRAM_NAME, ".pl" );     # get the name of this perl script (without the full path)
my @LOGDATA=();
my %ALREADY_EXISTS = ();
my %ALREADY_COPIED = ();
my $WORKING_COUNTER=0;
my $DEBUG=1;


MAIN :  {

	print "USERNAME: $USERNAME,  PROGRAM_PATH: $PROGRAM_PATH,  USERPROFILE: $USERPROFILE\n";

	open(*DEBUGFILE, ">backup_debug.txt") if ( $DEBUG );
	
	
	#my @info = ( "$USERPROFILE\\Documents", "G:\\backups\\scotty"  );  # SOURCEDIR, TARGETDIR ...
	
	my $drive = "G"; # MYBOOK3T < backup drive
	my $hdrive = "H"; # My Passport Ultra drive

	my $G_drive_root = "$drive:\\backups\\scotty\\_C_\\Users\\Kirk";
	my $H_drive_root = "$hdrive:\\backups\\scotty\\_C_\\Users\\Kirk";

	
	my @info = ( 
				 "$USERPROFILE\\AppData\\Local\\Microsoft\\Windows Live Mail", "$drive:\\backups\\photos-hp" ,"relative",
				 "$USERPROFILE\\Pictures",   "$drive:\\backups\\photos-hp" , "relative",
				 "$USERPROFILE\\Documents",  "$drive:\\backups\\photos-hp" , "relative",
				 "$USERPROFILE\\Videos",     "$drive:\\backups\\photos-hp" , "relative",
				 "$USERPROFILE\\Desktop",    "$drive:\\backups\\photos-hp" , "relative",
				 "$USERPROFILE\\Music",      "$drive:\\backups\\photos-hp" , "relative",
				 "E:\\JamesLaderoute\\Pictures",   "$G_drive_root\\Pictures" ,   "substitute",
				 "E:\\JamesLaderoute\\MySoftware", "$G_drive_root\\MySoftware" , "substitute",
				 "E:\\JamesLaderoute\\Documents",  "$G_drive_root\\Documents" ,  "substitute",
				 "E:\\JamesLaderoute\\Music",      "$G_drive_root\\Music" ,      "substitute",
				 "E:\\JamesLaderoute\\HP_Install_Kits",      "$G_drive_root\\HP_Install_Kits" ,  "substitute",
				 "E:\\JamesLaderoute\\Applications3rdParty", "$G_drive_root\\Applications3rdParty" ,  "substitute",
				 "E:\\JamesLaderoute\\Videos", "$G_drive_root\\Videos" ,  "substitute",

				 "E:\\JamesLaderoute\\Pictures",   "$H_drive_root\\Pictures" ,   "substitute",
				 "E:\\JamesLaderoute\\MySoftware", "$H_drive_root\\MySoftware" , "substitute",
				 );
				 
	
	while( @info ) {
		my $srcDir = shift @info;
		my $destRootDir = shift @info;
		my $processStyle = shift @info;
		
		# verify processStyle is either relative or substitute
		if ( $processStyle ne "relative")
		{
			if ( $processStyle ne "substitute")
			{
				print DEBUGFILE "-F- Bad processStyle \"$processStyle\" passed with $srcDir, $destRootDir\n";
				die "BAD SYNTAX IN \@info file !!!\n";
			}
		}
		
		undef @LOGDATA;
		%ALREADY_EXISTS = ();
				
		my $date_time = strftime "%m/%d/%Y", localtime;
		push(@LOGDATA, $date_time);
		
		print "doBackup $srcDir => $destRootDir\n";

		my $result = eval { doBackup($srcDir, $srcDir, $destRootDir, $processStyle); 1 };
		if ( $@ )
		{
			my $e = $@;
			push(@LOGDATA, "Something went wrong when doBackup was called with $srcDir $destRootDir: $e");
			print DEBUGFILE "Caught exception \"$e\"\n" if ( $DEBUG );
			print("Eval of doBackup has failed \"$e\" ... sleeping for 4 seconds\n");
			sleep(4);
		}
		
		
		saveLog( $srcDir ) if ( -e $srcDir );
	}

	print "DONE\n";
	
	close(DEBUGFILE) if ( $DEBUG );
	
	sleep(30);
	
}

sub saveLog
{
	my $sourceDir = shift;
	
	my $num = 1;
	my $logfile = "$sourceDir/backup.log";
	if ( -e $logfile )
	{
		copy( $logfile, $logfile.".bak" );
	}
		
	if ( ! open(*LOGFILE, ">$logfile" ) )
	{
		print "-F- Problem opening log file $logfile to be saved! $!\n";
		return;
	}
	
	
	
	foreach my $line ( @LOGDATA )
	{
		print LOGFILE "$line\n";
	}
	
	my $count = keys(%ALREADY_EXISTS);

	print LOGFILE "\n\n--- $count Items not copied because they already existed ---\n\n";

	
	close(LOGFILE);
	
	return;

}


sub doBackup
{
	my $topSourceDir = shift;
	my $sourceDir = shift;
	my $destinationRootDir = shift;
	my $processStyle = shift;       # relative=normal way,  substitute=new way


print DEBUGFILE "doBackup $topSourceDir  $sourceDir  $destinationRootDir $processStyle\n" if ( $DEBUG );
print  "doBackup $topSourceDir  $sourceDir  $destinationRootDir $processStyle\n" ;

	
	if ( ! -e $sourceDir ) 
	{
		print("-E- Failed to open SOURCE $sourceDir\n");
		push(@LOGDATA,"MISSING SOURCE FOLDER $sourceDir");
		return;
	}
	
	if ( ! -e $destinationRootDir )
	{
		print("-E- Failed to find destination root dir $destinationRootDir \n");
		print DEBUGFILE "doBackup unable to find destination $destinationRootDir \n" if ( $DEBUG );
		push( @LOGDATA, "MISSING DESTINATION ROOTDIR $destinationRootDir");
		return;
	}
	
	#
	# In case user chooses a folder that includes another folder already
	# copied, we will reduce repeated lookups by remembering which directories
	# we have already visited. And prevent going down that path again.
	#
	if ( exists( $ALREADY_COPIED{"$sourceDir $destinationRootDir"} ) )
	{
		print "REDUNDENT COPY OF $sourceDir\n";
		push(@LOGDATA, "REDUNDENT COPY OF $sourceDir");
		return;
	}
	
	$ALREADY_COPIED{"$sourceDir $destinationRootDir"} = 1;
	
	#
	# create a list of system files that we don't need to copy
	#	
	my %skipsystem;
	$skipsystem{"thumbs.db"}=1;
	$skipsystem{"desktop.ini"}=1;

	
	my @srcfiles;
	if ( ! opendir(SRCDIR, "$sourceDir"))
	{
		print "opendir FAILED \"$!\"  sourceDir=\"$sourceDir\"\n";
		print DEBUGFILE "opendir $sourceDir Failed\n" if ( $DEBUG );
		return;
	}	
	while ( my $file = readdir(SRCDIR) ) {
		push @srcfiles, "$file";
	}
	closedir(SRCDIR);
		
	foreach my $file ( @srcfiles)  {
		my $sourceFile = "$sourceDir\\$file";
		
		next if $file eq '.' or $file eq '..'; # for linux stuff
		
		$WORKING_COUNTER++;
		if ( $WORKING_COUNTER > 8000 )
		{
			print "    working... $sourceFile\n";
			$WORKING_COUNTER=0;
		}
		
		if ( -d $sourceFile )
		{
			#print "    DEBUG: -d \"$sourceFile\" calling doBackup \n" if ( $DEBUG);
			
			my $iresult = eval { doBackup( $topSourceDir, $sourceFile, $destinationRootDir, $processStyle ) ; 1 };
			if ( $@ )
			{
				print DEBUGFILE "Caught exception 2: \"$@\" doing $sourceFile  \n" if ( $DEBUG );
				print "Caught exception 2: \"$@\" \n";
				print "Sleep for 3 second\n";
				sleep(3);
			}
			next;
		}
		elsif ( ($file =~ m/^backup\.log/) or exists( $skipsystem{"$file"} ) )
		{
			next;
		}
		else
		{
			my $destFolder;
			
			if ( $processStyle eq "substitute")
			{
				# topsrc: C:/users/kirk/pictures   sourceDir:  C/users/kirk/pictures/2016/ab/cd    targetroot: G:/one/two/three/pictures 
				
				# we want to subsitute (ie. replace) the topsrc part of the destFolder with targetroot 
				
				
				my $nodeviceSourceDir = $sourceDir;
			#	print '$nodeviceSourceDir =~ s/\\/\\\\/g;' . "\n";
				$nodeviceSourceDir =~ s/\\/\\\\/g;
			#	print '$nodeviceSourceDir is now '. "$nodeviceSourceDir\n";
				my $modTopSourceDir = $topSourceDir;
				$modTopSourceDir =~ s/\\/\\\\\\\\/g;
			#	print '$modTopSourceDir is now '. "$modTopSourceDir\n";
			#	print '$nodeviceSourceDir(' . "$nodeviceSourceDir" . ') =~ s/'. "$modTopSourceDir" . '//;' . "\n";
				$nodeviceSourceDir =~ s/$modTopSourceDir//;
			#	print '$nodeviceSourceDir is now ' . "$nodeviceSourceDir\n";
				$destFolder = $destinationRootDir ;
				$destFolder = $destFolder . "\\$nodeviceSourceDir" if ( not ( $nodeviceSourceDir eq "" ));
				#print '$destFolder is now '. "$destFolder\n" if ( $DEBUG );
				
			}
			elsif ( $processStyle eq "relative")
			{
				#
				#  Replace the C: with _C_ , because don't think we can have a folder
				# by the name of C: - and we want to preserve this information in case
				# we have other drives that we want to backup.
				#

				my $nodeviceSourceDir = $sourceDir;
				$nodeviceSourceDir =~ s/C:/_C_/i;
				$nodeviceSourceDir =~ s/E:/_E_/i;
				$nodeviceSourceDir =~ s/G:/_G_/i;
				$destFolder = "$destinationRootDir\\$nodeviceSourceDir";
			}

			my $destinationFile = "$destFolder\\$file";
			
			if ( ! -d $destFolder )
			{
				if ( ! make_path( $destFolder ) )
				{
					print("-E- Failed to create destination folder: $destFolder : $!\n");
					push(@LOGDATA,"FAILED_DIR_CREATION $destFolder");
				}
			}

			print "sourceFile is $sourceFile ...\n" if ( $DEBUG );
			doCopy( "$sourceFile", "$destinationFile" );
		}
	}
	
	return;

}

sub doCopy
{
	my $src = shift;
	my $dest = shift;

		
	if ( -e $dest )
	{
		# ok, so the destination file already exists. We want to copy over it
		# only if the two files are different ; that is, if the source file is
		# newer than the dest file.
		
		#print "-I-EXISTS $dest, not re-copied\n";
		
		#push @LOGDATA, "EXISTS $dest";
		
		my $srcSize = -s $src;
		my $destSize = -s $dest;
		if ( $srcSize == $destSize )
		{
			$ALREADY_EXISTS{"$dest"}=1;
			return;
		}
	}
	
	
	if ( ! copy( "$src", "$dest" ) )
	{
		print "-E-FAILED_COPY src: $src => dest: $dest\n";
		push @LOGDATA, "COPYFAIL $src => $dest : $!";		
	}
	else
	{
		print "-I-COPIED src: $src => dest: $dest\n";
		push @LOGDATA, "COPY $dest";
	}
	
	return;
	
}


__END__
:endofperl





























