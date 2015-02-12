=head
Product Name : Crazy Downloader
Version		 : v1.2
Author		 : BeBinary(A.K.A Allwyn) & Mohammad Monis
URL 		 : http://sourceforge.net/projects/crazydownloader/  	 
Description  : 
		1. Helps you to download multiple files at a time
		2. Allow user to update to latest version
		3. Download using proxy server		
Known Issues :
		1. No scroll bar
		2. No cancelling of the downloads	
		3. No proxy authentication		
Implementation Issues :		
		1. No proper DS for maintaining Threads
		2. No reuse of threads which finishes the job early.
		3. No Logging
		4. Not getting file size. Have to use libcurl
		5. No proper validation like strings, proxy values
Feature Added:
		1. ProgressBar Support		
		2. StatusBar Support	
		3. Config file
=cut

use warnings;
use strict;
use LWP::UserAgent;
use Tk;
use Tk::StatusBar;
use Tk::Animation;
use threads;
use threads::shared;
use Thread::Suspend;  
use File::Spec;

#Shared variable for URL
my $url:shared = "";

#Shared variables for proxy
my $proxyValue:shared = "No Proxy";
my $addValue:shared;
my $portValue:shared;

#Shared variables for Limit
my $limitValue:shared = 15;

#Shared variables for updating downloading status
my $status:shared="Recent activitiy : Just open the App";
my @downloadStatus:shared = "";
my @statusMsg = "";

#File Download path
my $dwPath:shared ;

#Shared variables for ProgressBar 
my @progressBar:shared = "";
my $val:shared = 0;
my @Anim = "";
my $count = 0; 
my $noOfThreads = 10;

for( $count = 0; $count < $noOfThreads; $count++ )
{
	$progressBar[$count] = -1;
}

#Creating worker threads
$count = 0;
while ( $count < $noOfThreads )
{
	my $thr = threads->create( \&StartWorking );
	$count++;
}

# Main Window
my $windowY = 100;
my $mw = new MainWindow; 
$mw->geometry("580x100");
$mw->protocol('WM_DELETE_WINDOW' => sub { &clean_exit }); 
my $image = 'download.gif';    # 32x32 GIF or BMP
my $icon = $mw->Photo(-file => $image);
$mw->idletasks;        # this line is crucial
$mw->iconimage($icon);
$mw->title("Crazy Downloader");

#Menu
my $mbar = $mw -> Menu();
$mw -> configure(-menu => $mbar);

#The Menu Buttons
my $settings = $mbar -> cascade(-label=>"Settings", -underline=>0, -tearoff => 0);
$settings -> command(-label => "Proxy", -underline=>0,-activebackground => "blue", 
		-command=> [\&ProxySettings] );

$settings -> command(-label => "Change FilePath", -underline=>0,-activebackground => "blue", -command=> [\&ChangeDownloadPath] );		
		
#$settings -> command(-label => "Change Limit", -underline=>0,-activebackground => "blue", -command=> [\&LimitSettings] );		
		
$settings -> command(-label =>"Exit", -underline => 1,
		-command => [\&ExitTheApp]);	
		
my $about = $mbar -> cascade(-label=>"About", -underline=>0, -tearoff => 0);
$about -> checkbutton(-label =>"Features & Issues", -underline => 0,-activebackground => "blue",
		-command => [\&Features]);	
$about -> checkbutton(-label =>"CrazyDownloader", -underline => 0,-activebackground => "blue",
		-command => [\&About]);		

my $xValue = 10;
my $yValue = 40;

# URL label and entry 
my $lab = $mw -> Label(-text=>"URL",-relief=>"flat",-font=>"ansi 8 bold")->place(-x=>$xValue,-y=>10);
my $ent = $mw -> Entry(-width=>75)->place(-x=>$xValue + 40,-y=>10);
$ent->focus();

#Status Bar
my  $sb = $mw->StatusBar();

    $sb->addLabel(
		-width => 28,
        -text  => "Welcome to Crazy Downloader",
        -foreground     => 'blue',
    );
	
	$sb->addLabel(
		-width   => 70,
        -anchor   => 'center',
        -textvariable  => \$status,
        -foreground   => 'blue',
    );

my $avoidReplication = 1;#Avoid creating threads beyond noOfThreads
ReadConfigFile();

#Download button and creating status label
my $but = $mw -> Button(-text=>"Download", -font=>"ansi 8 bold",-command =>sub { $url = $ent->get(); $val += 1;
			$ent->delete('0','end');
			
			$yValue += 30;
			if( $val > $noOfThreads)
			{
				$val = 1;
				$avoidReplication = -1;
			}
			else
			{
				if ( $avoidReplication > 0)
				{
					
					$windowY += 30 ;
					$mw->geometry("580x".$windowY);
					$mw->Label(-textvariable=>\$statusMsg[$val], -font=>"ansi 8 bold", -background=>"white")->place(-x=>$xValue,-y=>$yValue);						
					
					$Anim[$val] = $mw->Animation(
							  -format => 'gif',
							  -file   => 'progress_circle.gif'
							);
							
					my $NrFrame = $#{ $Anim[$val]->{'_frames_'} };
					$Anim[$val]->add_frame($Anim[$val]);
					$Anim[$val]->start_animation();
					$Anim[$val]->set_image( 0 .. $NrFrame );

					$mw->Label( -image => $Anim[$val], )->place(-x=>500,-y=>$yValue);						
				}	
			}	
			foreach my $thr (threads->list()) 
			{
				if( $thr->tid() == $val )
				{
					$thr->resume();
					goto OUTSIDE;
				}
			}
			OUTSIDE:												
			
			})->place(-x=>$xValue + 500 ,-y=>6);
			
my $down = $mw->Label(-text=>"Download Details",-font=>"ansi 10 bold", -foreground=>"blue",)->place(-x=>220,-y=>50);			

my $timer = $mw->repeat(10,sub{
            foreach my $thr (threads->list()) 
			{
				$statusMsg[$thr->tid()] = $downloadStatus[$thr->tid()];
			}
			
			for( $count = 0; $count < $noOfThreads; $count++ )
			{				
				if( $progressBar[$count] != -1 )
				{
					$Anim[$count]->stop_animation(); 
					$progressBar[$count] = -1; 
				}
			}
			
        });

$mw->resizable( 0, 0 ); 		
MainLoop;

#Read from config file
sub ReadConfigFile
{
	open(FILE,"crazydownloder.cfg");

	my @temp;
	
	print "ff";
	
	while (my $line = <FILE>) 
	{
		next if $line =~ /^#/;        # skip comments
		next if $line =~ /^\s*$/;     # skip empty lines
		@temp = split('=',$line);
		
		if( $temp[0] eq "proxy_server")
		{
			my @proxy = split(':',$temp[1]);
			$addValue = $proxy[0];
			$portValue = $proxy[1]; 
		}
		if( $temp[0] eq "server")
		{
			$proxyValue = $temp[1];	
			chomp($proxyValue);			
		}
		if( $temp[0] eq "path")
		{
			$dwPath = $temp[1];
			chomp($dwPath);
			
		}
	}
	
	if( $dwPath eq "" )
	{
		my $path = $ENV{'USERPROFILE'};
		$path =~s/\\/\//g;
		$dwPath= "$path/Desktop";
	}
	
	close(FILE);
}

#Write into config file
sub WriteConfigFile
{
	open(FILE,">crazydownloder.cfg");

	print FILE "#Proxy Server Details\n";
	print FILE "proxy_server=".$addValue.":".$portValue;
	print FILE "\n";
	print FILE "#Servver Selection\n";
	print FILE "server=".$proxyValue;
	print FILE "\n\n";
	print FILE "#Download File Path\n";
	print FILE "path=".$dwPath;
	print FILE "\n";
	
	close(FILE);
}

#Handles proxy settings
sub ProxySettings
{
	my $top = $mw -> Toplevel(); #Make the window	
	$top->title("Proxy Settings");
	$top->geometry("250x130");
	
	my $image = 'download.gif';    # 32x32 GIF or BMP
	my $icon = $top->Photo(-file => $image);
	$top->idletasks;        # this line is crucial
	$top->iconimage($icon);
		
	my $settings = $top->Frame()->pack(-side => "top");
	
	$settings -> grid(-row=>1,-column=>1,-columnspan=>10);

	my $address = $settings -> Entry(-text=>$addValue);
	my $port = $settings -> Entry(-text=>$portValue);
	
	if ( $proxyValue eq "No Proxy")
	{
		$address->configure(-state=>'disabled');
		$port->configure(-state=>'disabled');
	}
	
	my $rb_1 = $settings->Radiobutton(-text => "No Proxy", -value => "No Proxy",,-relief=>"flat",
                         -variable => \$proxyValue,-command=>sub{$address->configure(-state=>'disabled');$port->configure(-state=>'disabled')});
	my $rb_2 = $settings->Radiobutton(-text => "Manual Proxy", -value => "Manual Proxy",,-relief=>"flat",
                         -variable => \$proxyValue,-command =>sub{ $settings -> messageBox(-title=>"Crazy Downloader",-message=>"Change if default address is not correct",-type=>'ok',-icon=>'info');$address->configure(-state=>'normal');$port->configure(-state=>'normal') });
		
	my $addressLab = $settings -> Label(-text=>"Proxy Address",-relief=>"flat");
	my $portLab = $settings -> Label(-text=>"Proxy Port",-relief=>"flat");
	my $apply = $settings -> Button(-text=>"Save and Exit", -command => sub { $addValue = $address -> get(); $portValue = $port -> get();
													
										if( $addValue eq "" || $portValue eq "" )
										{		
											$settings -> messageBox(-title=>"Crazy Downloader",-message=>"Empty value not allowed",-type=>'ok',-icon=>'info');
											$proxyValue = "No Proxy";
											$address->configure(-state=>'disabled');
											$port->configure(-state=>'disabled');
										}
										else
										{	
											$status = "Recent activitiy : Open/Changed Proxy Settings";	
											destroy $top;
										}	
									});
	
	$rb_1 -> grid(-row=>1,-column=>1,-ipadx =>1, -ipady =>4);
	$rb_2 -> grid(-row=>1,-column=>2,-ipadx =>1, -ipady =>4);
	
	$addressLab -> grid(-row=>3,-column=>1,-ipadx =>1, -ipady =>4);
	$address -> grid(-row=>3,-column=>2,-ipadx =>1, -ipady =>4);
	
	$portLab -> grid(-row=>5,-column=>1,-ipadx =>1, -ipady =>4);
	$port -> grid(-row=>5,-column=>2,-ipadx =>1, -ipady =>4);
	
	$apply -> grid(-row=>7,-column=>2,-ipadx =>17, -ipady =>4);
	
	$top->resizable( 0, 0 ); 		
}

#Change Download File Path
sub ChangeDownloadPath
{
	my $top = $mw -> Toplevel(); #Make the window	
	$top->title("Change Download File Path");
	$top->geometry("500x60");
	my $Directory;
	
	my $image = 'download.gif';    # 32x32 GIF or BMP
	my $icon = $top->Photo(-file => $image);
	$top->idletasks;        # this line is crucial
	$top->iconimage($icon);
	
	$top -> Label(-text=>"FilePath")->place(-x=>20,-y=>12);	
	my $ent = $top -> Entry(-width=>58,-textvariable=>\$dwPath, -state=>"readonly", -background=>"white")->place(-x=>75,-y=>12);
	$top -> Button(-text=>"Change", -command => sub {
							$Directory = $mw->chooseDirectory(
							  -title      => "Please choose the folder",
							  -initialdir => \$dwPath,
							  -mustexist  => 1,
							);
							$dwPath = $Directory;
							
							$status = "Recent activitiy : Open/Changed File Path Settings";	
							
							if( ! defined $dwPath)
							{
								$dwPath = ".";
							}
							
						}
					)->place(-x=>438,-y=>10);
					
	$ent->insert(0,$dwPath);	
	$top->resizable( 0, 0 ); 
}

#Change the Limit
sub LimitSettings
{
	my $top = $mw -> Toplevel(); #Make the window	
	$top->title("Limit");
	
	my $image = 'download.gif';    # 32x32 GIF or BMP
	my $icon = $top->Photo(-file => $image);
	$top->idletasks;        # this line is crucial
	$top->iconimage($icon);
	
	$top->geometry("180x80");
	
	$top -> Label(-text=>"Size Limit")->place(-x=>20,-y=>10);	
	my $limit = $top -> Entry(-width=>10,-text=>"15")->place(-x=>75,-y=>10);
	$top -> Label(-text=>"MB")->place(-x=>130,-y=>10);
	
	my $apply = $top -> Button(-text=>"Save and Exit", -command => sub { 
								$limitValue = $limit -> get(); 
								if( $limitValue =~ /^[+-]?\d+$/ && $limitValue gt 1)
								{
									destroy $top;
								}
								else
								{
									$top -> messageBox(-message=>"Please specify correct limit",-type=>'ok',-icon=>'info');
								}
							}
						)->place( -x=>95,-y=>54);
												
	$top->resizable( 0, 0 ); 		
}

#Features and Issues Menu
sub Features
{
	my $top = $mw -> Toplevel(); 
	$top->title("Features & Issues");
	$top->geometry("380x160");
	
	my $image = 'download.gif';    # 32x32 GIF or BMP
	my $icon = $top->Photo(-file => $image);
	$top->idletasks;        # this line is crucial
	$top->iconimage($icon);

	$top -> Label(-text=>"Features :", -font=>"ansi 8 bold") -> place(-x=>10, -y=>10);
	$top -> Label(-text=>"1. User can download file using proxy settings.", -font=>"ansi 8 bold") -> place(-x=>40,-y=>30);		
	$top -> Label(-text=>"2. User can download 10 files simultaneously.", -font=>"ansi 8 bold") -> place(-x=>40,-y=>50);		
	
	$top -> Label(-text=>"Issues :", -font=>"ansi 8 bold") -> place(-x=>10, -y=>80);
	$top -> Label(-text=>"1. User cant specify authentication details for proxy server.", -font=>"ansi 8 bold") -> place(-x=>40,-y=>100);		
	$top -> Label(-text=>"2. User cant cancel the download.", -font=>"ansi 8 bold") -> place(-x=>40,-y=>120);		
			
	$top->resizable( 0, 0 ); 				

}

#About menu
sub About 
{
	my $top = $mw -> Toplevel(); 
	$top->title("About Crazy Downloader");
	$top->geometry("300x70");
	
	my $image = 'download.gif';    # 32x32 GIF or BMP
	my $icon = $top->Photo(-file => $image);
	$top->idletasks;        # this line is crucial
	$top->iconimage($icon);

	$top -> Label(-text=>"Author   : BeBinary", -font=>"ansi 8 bold") -> place(-x=>20,-y=>20);		
	$top -> Label(-text=>"HomePage : http://bebinary.wordpress.com/", -font=>"ansi 8 bold") -> place(-x=>20,-y=>40);	
			
	$top->resizable( 0, 0 ); 				
}

#Exit the App
sub ExitTheApp 
{
	my $response = $mw -> messageBox(-title=>"Crazy Downloader",-message=>"Really quit?",-type=>'yesno',-icon=>'question');
	if ( $response eq "Yes" ) 
	{
		clean_exit();
	}
}

#Kill all the running threads
sub clean_exit
{
	$timer->cancel;
	my @running_threads = threads->list;
	if ( scalar(@running_threads) < 1 )
	{
		WriteConfigFile();
		exit;
	}
	else
	{
		foreach my $thr (threads->list()) 
		{
			$thr->kill('KILL')->detach();
		}
		WriteConfigFile();
		exit;
	}
}

#Calling all the necessary functions
sub StartWorking
{
	WAIT:

	$SIG{'KILL'} = sub { threads->exit(); };
	threads->self()->suspend();	
	
	my $localURL = $url;	
	
	$downloadStatus[threads->tid()] = threads->tid().". Verfying URL -> ".$localURL;
	
	if( $localURL eq "" )
	{
		$downloadStatus[threads->tid()] = threads->tid().". Please specify the url. ";
		$progressBar[threads->tid()] = 0;
		goto WAIT;
	}
	
	if( !( $localURL =~ /http:/) )
	{
		$localURL = "http://".$localURL;
	}
	
	my $verifyUrl = ValidateURL( $localURL);
	
	if( $verifyUrl == 1 )
	{
		$downloadStatus[threads->tid()] = threads->tid().". URL does not exist or timeout or due to proxy server. ".$url;
		$progressBar[threads->tid()] = 0;
		print threads->tid(). " ".$progressBar[threads->tid()] ;
		goto WAIT;
	}
	else
	{
		my $name = GetFileName( $localURL );	
		my $result = StartDownload( $name, $localURL );
		
		if ( $result eq 0 )
		{
			$downloadStatus[threads->tid()] = threads->tid().". Download completed : ".$name;
			$progressBar[threads->tid()] = 0;
		}
		else
		{
			$downloadStatus[threads->tid()] = threads->tid().". Download failed :".$name;
			$progressBar[threads->tid()] = 0;
		}
	}	
		
	goto WAIT;
}

#Check whether given url is valid or not
sub ValidateURL
{

	my $ua = LWP::UserAgent->new;
		
	if ( $proxyValue eq "Manual Proxy")
	{
		 $ua->proxy(['http', 'ftp'], 'http://'.$addValue.':'.$portValue.'/');
	}
			
	my $resp = $ua->get( $url,
					Range  => 'bytes=0-10'
				) or die;		

	if ( $resp->is_success ) 
	{			
		return 0;
	}
	return 1;	
}		

#Get the filename from URL. If file name already exist, append number before filename
sub GetFileName
{
	$status = "Recent activitiy : Started downloading ";
	my $fname;
	my $count = 1;
	my $url = shift;
	my $index = rindex ( $url, '/' );
	$fname = substr( $url, $index + 1);
	
	my $dir = $dwPath."/";
	
	if( -e $dir.$fname)
	{
		while( -e $count."_".$fname)
		{
			$count++;
		}
	}
	else
	{
		return $fname;
	}
	return $count."_".$fname;
}

#Get the file size before downloading starts
sub GetFileSize
{ 
    my $url=shift;
    my $uObj = new LWP::UserAgent;
    $uObj->agent("Mozilla/5.0");

	if ( $proxyValue eq "Manual Proxy")
	{
		 $uObj->proxy(['http', 'ftp'], 'http://'.$addValue.':'.$portValue.'/');
	}
			
	my $req = new HTTP::Request 'HEAD' => $url;
    $req->header('Accept' => 'text/html');
    my $res = $uObj->request($req);
	
	
	if ( $res->is_success ) 
	{
		my $headers = $res->headers;
		my $fileSize = $headers->content_length;
        return $fileSize;
    }
	
	return 0;
}

#Start downloading by splitting into 15MB
sub StartDownload
{
	my ( $fileName, $url ) = @_;
	
	use integer;
		
	my $byte = 1048576;	
	my $start = 0;
	my $end = $byte;
		
	for ( ;; )
	{	
	
		my $tempName = $dwPath."/".$fileName;
		
		open(FILE, '>>'.$tempName);
		binmode (FILE);	
	
		my $ua = LWP::UserAgent->new;
		
		if ( $proxyValue eq "Manual Proxy")
		{
			 $ua->proxy(['http', 'ftp'], 'http://'.$addValue.':'.$portValue.'/');
		}
		
		$downloadStatus[threads->tid()] = threads->tid().". ".$fileName." downloading....Please wait";
		
		my $resp = $ua->get( $url,
					Range  => 'bytes='.$start.'-'.$end
					) or die;				
					
		if ( $resp->is_success ) 
		{
			print FILE $resp->content;
			close(FILE);
			
			my $filesize = -s $tempName;
			print $tempName." ". $filesize;
			
			if( ( $filesize - 1) ne $end)
			{
				return 0;
			}		
		}			
		
		$start = $end + 1;
		$end = $end + $byte;
		
	}				
}
