#!/usr/bin/perl -w

# parser for DIO chat messages spamming Grepolis browser game
#
# Example messages can be downloaded from https://diotools.de/php/getMessages.php?world=de92
# delivering a json array of message objects in a timely manner.
#
# Example message looks link:
#  {
#    "time": "<epoch-value>",
#    "player": "<player-name>",
#    "message": "<player-message>",
#    "ip": "<player-ip>"
#  }
#
# version history
#    1.0   initial release
#    1.1   added "user" processing mode

use strict;
use JSON;
use JSON::Parse 'json_file_to_perl';
use Pod::Usage qw(pod2usage);
use Getopt::Std;
#use Data::Dumper;
use LWP::UserAgent;
use HTML::Entities;
use Text::Unidecode qw(unidecode);
use DateTime;
use DateTime::Format::Strptime;
use List::Util qw(min uniq);
 
$Getopt::Std::STANDARD_HELP_VERSION = 1; 
our $VERSION = '1.1'; 
 
# command line options parsing
my %opts = ();
getopts('m:o:p:n:i:s:u:h?', \%opts) or pod2usage(-exitstatus => 2, -verbose => 1);
pod2usage(-exitstatus => 1, -verbose => 3) if ($opts{'?'} or $opts{h});

my ($mode, $world, $file, $ip, $list, $process, $restrict, $start, $user);

# get script mode, either look up for message index, download chat file or process stored chat file 
pod2usage(-message => "no mode selected, select either 'download' or 'process'",
          -exitstatus => 1,
		  -verbose => 0) unless defined $opts{m} and $opts{m} =~ m/^(download|process|index)$/;
$mode = $opts{m};

# basic variable assignment
$world = $opts{o} if $mode eq 'download' or $mode eq 'index';
$file = $opts{o} if $mode eq 'process';
$process = $opts{p} if $mode eq 'process';
$restrict = -1;
$restrict = $opts{n} if $opts{n};
$start = 1;
$start = $opts{s} if $opts{s};
$user = $opts{u} if $opts{u};

# verify options, strongly depending on mode
die "unknown format for world identifier: $world\n" if $mode =~ m/^(download|index)$/ and $world !~ m/^\w{2}\d{2,3}$/;
die "no such file $file\n" if $mode eq 'process' and not -e $file;
die "no parser mode set\n" if $mode eq 'process' and $process !~ m/^(addresses|ip|multi|stats|start|user)$/; 
die "no ip given\n" if $mode eq 'process' and $process eq 'ip' and not $opts{i};
die "not an ip address $opts{i}\n" if $opts{i} and $opts{i} !~ m/^(\d+\.\d+\.\d+\.\d+)$/;

# initialize json decoder
my ($json) = JSON->new->allow_nonref;

# define constant objects
my $msg_time_format = DateTime::Format::Strptime->new( pattern => '%Y.%m.%d %H:%M:%S' );
my $dio_script_uri = "https://diotools.de/php/getMessages.php";

if ($mode =~ m/^(download|index)$/)
{
	# "online" functionality
	
    my $ua = LWP::UserAgent->new;
    my $uri = $dio_script_uri . '?' . 'world=' . $world;
	$uri .= '&id=1' if ($mode eq 'download');
 
    # set custom HTTP request header fields
    my $req = HTTP::Request->new(GET => $uri);
    $req->header('content-type' => 'application/json');
 
	# call dio service
    my $message;
    my $resp = $ua->request($req);
    if ($resp->is_success)
	{
        my $message = $resp->decoded_content;
	    
		if ($mode eq 'index')
		{
			print "last index of world $world: " . $json->decode($message)->[0]->{last_id} . "\n";
		}
		else
		{
			my $filename = "$world.json";
			print "writing output to file $filename...\n";
            open (FILE, ">" . $filename);
			print FILE $message;
			close FILE;
		}
    }
    else
	{
		die "network connection failed on : $uri (" . $resp->code . ", " . $resp->message .")\n";
    }
	
	# everything ok, no need to continue
	exit (0);
}

# processing mode, read chat input from file
print "read input file: $file\n";

my @messages = ();

my $json_text = do {
    open(my $json_fh, "<:encoding(UTF-8)", $file) or die("Can't open \"$file\": $!\n");
    local $/;
    <$json_fh>
};

# initially parse all messages to list
my $json_data = $json->decode($json_text);
foreach my $line (@{$json_data}) {
	next if $line->{last_id};
		
	my $dt = DateTime->from_epoch( epoch => $line->{time} );		
		
	my %h = ('player' => unidecode($line->{player}), 'time' => $msg_time_format->format_datetime($dt), 'message' => unidecode(decode_entities($line->{message})), 'ip' => $line->{ip});
	push @messages, \%h;
}

my %players = ();
my %m_count = ();
my %ips_players = ();

# build up player->ip-list and player->message-count hashes
foreach my $message (@messages)
{
	my $player = %{$message}{player};
	my @ips = ($message->{ip});
		
	if (defined $players{$player})
	{
		push @ips, @{$players{$player}};
		@ips = uniq(@ips);
	}
	if (defined $m_count{$player})
	{
		$m_count{$player} += 1;
	}
	else
	{
		$m_count{$player} = 1;
	}

	$players{$player} = \@ips;
}

printf "parsed %d messages.\n", scalar @messages;

# build up ip->player-list hash
foreach my $message (@messages)
{
	my @players = ($message->{player});
	my $ip = $message->{ip};
	
	push @players, @{$ips_players{$ip}} if (defined $ips_players{$ip});
	
	$ips_players{$ip} = \@players;
}

printf "identified %d players.\n", scalar keys %ips_players;

if ($process eq 'start')
{
	# start mode, deliver n message after given position
	my $count = 0;
	
    foreach my $message (@messages)
    {
		next if $count++ < $start; # skip until index
		
		printf "%s : %s : %40s\n", $message->{time}, $message->{player}, $message->{message};
		
		last if $restrict > 0 and $count > $start + $restrict - 1; # break if maximum amount of messages have been reached
	}
}
elsif ($process eq 'ip')
{
	# ip mode, lists player name and message using given ip
    # hash ip -> hash timestamps -> hash (player, message)
    my $r_ip = $opts{i};
    my %ips_timestamps = ();
    foreach my $message (@messages)
    {
	    my @ips = $message->{ip};
	    my $ip = $message->{ip};
	    next unless $ip eq $r_ip; # skip if not ip we are looking for

	    my $timestamp = $message->{time};
	
	    my %entry = ( 'player' => $message->{player} , 'message' => $message->{message} );
	    $ips_timestamps{$timestamp} = \%entry;
    }
	
	# print out messages of given ip
    foreach my $p (sort keys %ips_timestamps)
    {
	    printf "%s : %s : %20s\n", $p, $ips_timestamps{$p}->{player}, $ips_timestamps{$p}->{message}; 
    }
}
elsif ($process eq 'multi')
{
	# multi mode, looking for ips with more than one player assigned to
    foreach my $p (keys %ips_players)
    {
	    my @_players = @{$ips_players{$p}};
	
	    my @uniq_players = uniq(@_players);
	    my @min = ();

		# prepare output
	    my $player_string = '';
	    foreach my $player (@uniq_players)
	    {
		    $player_string .= " " if $player_string;
		    my $count = grep {/\Q$player\E/}@_players;
		    push @min, $count;

		    $player_string .= $player . " (" . $count . ")";
	    }
	
		# only enlists ip with more than one uniq player
	    if ($#uniq_players > 0 and min(@min) > 1)
	    {
		    printf ("%-20s : %s\n", $p, $player_string);
	    }
    }
}
elsif ($process eq 'user')
{
	die "no player given\n" unless $user;
    die "no messages registered for user $user\n" unless $players{$user};
	
	my @ips = @{$players{$user}};
	
	print $user . " is using " . scalar @ips . " ips.\n";
	
    my $ua = new LWP::UserAgent();
	
	foreach my $i (@ips)
	{
		my @_players = @{$ips_players{$i}};
		
		my $count = grep {/\Q$user\E/}@_players;
	
		my $get = $ua->get('http://extreme-ip-lookup.com/json/' . $i)->content;
		my $geo = decode_json $get;
		printf "%18s (%4d): %-20s %-40s %-40s\n", $i, $count, $geo->{'city'}, $geo->{'isp'}, $geo->{'ipName'};
	}
}
elsif ($process =~ m/^(stats|addresses)$/)
{
	# stats and addresses mode
	my $count = 0;
    foreach my $p (sort { $m_count{$b} <=> $m_count{$a} } keys %m_count) # sort descending
    {
	    my $count_ips = scalar @{$players{$p}};
	    my $ratio = $m_count{$p} / $count_ips / $m_count{$p} * 100;
	    
		printf ("%-30s (%3d) : %s\n", $p, $m_count{$p}, join(" ", @{$players{$p}})) if $process eq 'addresses'; # lists players using ips
	    printf ("%-30s (%4d messages) (%3d different ips) (%3d%% messages per ip)\n", $p, $m_count{$p}, $count_ips, $ratio) if $process eq 'stats'; # lists top n poster

		# optional break condition
		$count++;
		last if $restrict > -1 && $count >= $restrict;
    }
	printf "summing %3d players writing %5d messages.\n", scalar (keys %m_count), scalar(@messages);
}

# called by Getopt::Std when supplying --help option
sub HELP_MESSAGE
{
    pod2usage(-exitstatus => 2, -verbose => 2);
}

# called by Getopt::Std when supplying --version or --help option
sub VERSION_MESSAGE
{
    print "Version $VERSION\n";
}

__END__

=head1 NAME

stat_dio_chat - collects statistics from dio chat protocol for browser game Grepolis

=head1 SYNOPSIS

  stat_dio_chat.pl [options]

  Options:

   -m     script mode, one-of (download|index|process)
   -o     option parameter for mode
   -p     process mode, one-of (stats|multi|ip|addresses|start)
   -n     restrict output
   -i     ip adddress
   -s     start index
   -u     player name
   -h     this helpfile

  Examples:
    
    See the following example on working with world C<de92>. We start with downloading the complete chat log to C<de92.json> and afterwards extract some information.

       stat_dio_chat.pl -m download -o de92
	   
    Lets see some statistics, optionallay limiting output to three entries
	
       stat_dio_chat.pl -m process -o de92.json -p stats -n 3

    Find out all ip-addresses that are used by more than one player
	
       stat_dio_chat.pl -m process -o de92.json -p multi
	   
    List all messages attached to a certain ip-address
	
       stat_dio_chat.pl -m process -o de92.json -p ip -i <ip-address>
	   
    List all ip addresses assigned to e certain user
    
       stat_dio_chat.pl -m process -o de92.json -p user -u <user-name>
		
    Finally list ten messages after given index
	
      stat_dio_chat.pl .m process -o de92.json -p start -s 1000 -n 10
   
=head1 DESCRIPTION

The browser script C<DIO-Tools> is an add-on for the game C<Grepolis>, that contains a chat function. This chat function is uploading player messages to a centralized web based location that can easily addressed by noisy people. This scripts provides easy access to stored chat logs. For performance sake it also contains persisting current world chats on users local file storage so online parsing is prohibited.

=head1 OPTIONS

=over 4

=item B<-m modus>

=over 8

=item C<download>

Downloads live chat, additionally needs world as parameter, see C<-o>
Writes output as json to generated filename from worldcode, e.g. I<de92.json>

=item C<index>

Returns last chat message id to console, additionally needs world as parameter, see C<-o>

=item C<process>

processes already downloaded file, additionally needs input file (see C<-o>) and process mode (see C<-p>)

=back

=item B<-o option parameter>, depending on used I<mode>

=over 8

=item C<download>

In download mode referes to internal world code to download, e.g. C<de92>

=item C<index>

In index mode referes to internal world code to download, e.g. C<de92>

=item C<process>

In process mode referes to filemame to load from, e.g. C<de92.json>

=back

=item B<-p process>

One of C<addresses>, C<ip>, C<multi>, C<stats> or C<start>

=over 8

=item C<addresses>

Lists ip addresses of players.

=item C<ip>

Lists all messages using given ip-address, additionally needs parameter I<-i ip>

=item C<multi>

Lists ip-addresses that are used by different player names and amount of their posts.

=item C<stats>

Shows current player posting stats, ordered by amount of posts. Can be restricted by I<-n number>.
Additionally lists amount of different ip-addresses a player is using as well as a messages-per-ip ratio.

=item C<start>

Show amount of messages after start index, additionally set by i<-s number>. Can be restricted by I<-n number>.

=item C<user>

Lists all ip-addresses subscribed to a user, additionally needs parameter I<-u player name>

=back

=item B<-i ip-address>

IP-Address to list messages for. Only to be used in processing mode C<ip>.

=item B<-s number>

Starting index when displaying n-th chat message in timelime. Only to be used in processing mode C<start>.

=item B<-n number>

Restrict output to ámount of C<n> entries. Can be used in conjunction with processing modes C<stats>, C<start> and C<multi>.

=back

=head1 COPYRIGHT

Copyright 2018 Dr. Naseweis E<lt>dr.naseweis@protomail.comE<gt>

=head1 AUTHOR

Dr. Naseweis E<lt>dr.naseweis@protonmail.comE<gt>

=cut
