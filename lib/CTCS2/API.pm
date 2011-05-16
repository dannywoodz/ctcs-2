package CTCS2::API;

###############################################################################
#
=pod

=head1 NAME

CTCS2::API

=head1 DESCRIPTION

This module provides simple access to the new API introduced in CTCS2 1.1.

Unlike CTCS2 itself, which is intended to run on a vanilla Perl 5.8 with no
additional modules installed, this API requires JSON::XS, which is available
on CPAN (the assumption is that you're a programmer if you're messing with the
API, and are comfortable customising your Perl install with new modules).

=head1 EXAMPLES

=over 4

use CTCS2::API;

my $api    = CTCS2::API->new();
my $active = $api->active();

printf "%d active torrents\n", $active->{count};

# Simple one-by-one pause

foreach my $torrent (@{$active->{torrents}})
{
  $api->pause($torrent->{id});
}

# More efficient batch pause (less network chat)

my @ids = map { $_->{id} } @{$active->{torrents}};
$api->pause(@ids);

=back

=head1 CLASS METHODS

=over 4

=item new([hostname = 'localhost' [, port=8080 ]])

Creates a new API object.  The default host is 'localhost'; the default port
is 8080.  These can be overridden by optional arguments: the host first, the
port second:

=over 4

CTCS2::API->new();                  # 'localhost', port 8080
CTCS2::API->new('some-host');       # 'some-host', port 8080
CTCS2::API->new('some-host', 8000); # 'some-host', port 8000

=back

=back

=head1 INSTANCE METHODS

=over 4

=item pause

By default, pauses all torrents on the server.  If supplied with one more
torrent ids, will instead pause only those torrents.  Returns a hash
reference with the keys 'action' and 'torrents'.  The value associated with
'action' is 'pause'.  The value associated with 'torrents' is a list
reference containing one hashref per torrent, with the keys 'name' and 'id'.

=item resume

See the documentation for 'pause' above.  The value associated with the
'action' key is 'resume'

=item update

See the documentation for 'pause' above.  The value associated with the
'action' key is 'update'

=item active

Returns a hashref detailing active (i.e. non-paused) torrents.  The keys
are 'count', 'torrents' and 'status', with the values being the number of
active torrents, a list ref of torrents (as with the 'pause' method) and
the string 'active', respectively.

=item paused

As with 'active', above, but detailing paused torrents and having the value
'paused' associated with the 'status' key.

=item torrents

As with 'active', above, but detailing all registered torrents, active or
paused, and having the value 'registered' associated with the 'status' key.

=item torrent_status

Provides a detailed list of all registered torrents.  Returns a list reference
of hashrefs, where each hashref describes a single torrent.  Each hashref has
the keys 'id', 'name', 'percent_complete', 'time_remaining', 'download_rate',
'upload_rate', 'seeders', 'leechers', 'downloaded', 'uploaded', 'size',
'ratio' and 'paused'.

If given one or more torrent ids, this method restricts the report to the
specified torrents.

=item get_bandwidth_limits

Returns a hash reference with the keys 'download-limit' and 'upload-limit',
with the values being in bytes/second.  These are the LIMITS for the server,
not the current totals (see get_bandwidth_totals for that measure).

=item set_bandwidth_limits

Sets the bandwidth limits on the server, using the values attached to the keys
'upload-limit' and 'download-limit' (measured in bytes/second) in the given
arguments.

i.e.

=over 4

$api->set_bandwidth_limits( 'upload-limit' => 102400 );

$api->set_bandwidth_limits( 'upload-limit' => 51200, 'download-limit' => 102400 );

$api->set_bandwidth_limits( 'download-limit' => 0 );

=back

=item get_bandwidth_totals

Reports the currently used upload/download bandwidths.  The hashref returned
has the keys 'upload-rate' and 'download-rate', with values measured in
bytes/second.

=item get_config

Reports the configurations for all registered torrents.  If given one or
more torrent ids, restricts the report to the specified torrents.  The
hashref returned has the keys 'action' and 'configs'.  The value associated
with 'action' is 'get-config', and the one associated with 'configs' is a
list of configurations, one per torrent.  Each configuration is a hashref,
with the keys 'torrent', 'id' and 'config'.

=item set_config

Requires a single torrent id, and sets the configuration parameters in
the supplied hash on that torrent.  Keys should be the ctorrent configuration
parameters.

$api->set_config('ctcs-torrent-4',
                 'seed_ratio' => 1.5,
                 'ctcs_server' => 'new-host:8002');

Returns the same as 'get-config' when done.

=item quit

Quits the torrent(s) with the given id(s).  If given no ids, will NOT quit
anything, but instead return a hashref with the key 'error' and the value
'explicit torrent ids are required for the quit API call'.  With one or more
ids, will return a hashref with the keys 'action' and 'torrents', with the
values 'quit' and a torrent summary for each torrent quit (hashref with
'id' and 'name' fields), respectively.

=item make_api_all

Allows the sending of a 'raw' API message.  All API methods ultimately use
this method to get something done.  For example, the 'pause' method can be
replicated as:

=over 4

$api->make_api_all('pause');

or

$api->make_api_call('pause', ['ctcs-torrent-2', 'ctcs-torrent-3']);

=back

This method requires at least one argument (the remote name of the API function, e.g.
'pause' or 'quit').  The optional second parameter must be a list REFERENCE of
torrent ids to work with (may be undef, depending on what the API function
requires).  Any additional arguments are interpreted as key/value pairs for
specifying HTTP params, e.g.:

=over 4

$api->make_api_all('set-bandwidth-limits', undef, 'upload-limit' => 51200, 'download-limit' => 0);

=back

Frequent use of this method implies a hole in the API interface, as it really
shouldn't be used.

=back

=head1 AUTHOR

Danny Woods (dannywoodz@yahoo.co.uk)

=head1 LICENCE

CTCS2::API is released under the same license as CTCS2 itself.

=cut
#
###############################################################################

use HTTP::Request;
use LWP::UserAgent;
use JSON::XS;
use constant URL_TEMPLATE => 'http://%s:%d/api/%s';

sub new
{
  my $class = shift;
  my $self  = {};

  $self->{host} = shift || 'localhost';
  $self->{port} = shift || 8080;

  return bless($self, $class);
}

sub pause
{
  return shift->make_api_call('pause', \@_);
}

sub resume
{
  return shift->make_api_call('resume', \@_);
}

sub update
{
  return shift->make_api_call('update', \@_);
}

sub active
{
  return shift->make_api_call('active');
}

sub paused
{
  return shift->make_api_call('paused');
}

sub torrents
{
  return shift->make_api_call('torrents');
}

sub torrent_status
{
  return shift->make_api_call('torrent-status', \@_);
}

sub get_bandwidth_limits
{
  return shift->make_api_call('get-bandwidth-limits');
}

sub set_bandwidth_limits
{
  return shift->make_api_call('set-bandwidth-limits', undef, @_);
}

sub get_bandwidth_totals
{
  return shift->make_api_call('get-bandwidth-totals');
}

sub quit
{
  return shift->make_api_call('quit', \@_);
}

sub set_config
{
  my ($self, $torrent_id, @params) = @_;
  return $self->make_api_call('set-config', [$torrent_id], @params);
}

sub get_config
{
  return shift->make_api_call('get-config', \@_);
}

sub get_log_level
{
  return shift->make_api_call('get-log-level');
}

sub set_log_level
{
  return shift->make_api_call('set-log-level', undef, 'log-level' => shift);
}

sub id_for_name
{
  return shift->make_api_call('id-for-name', undef, 'name' => shift);
}

sub make_api_call
{
  my ($self, $call, $torrent_ids, %params) = @_;

  my $request = HTTP::Request->new('POST', sprintf(URL_TEMPLATE, $self->{host}, $self->{port}, $call));
  my $agent   = LWP::UserAgent->new();
  my @params;

  push(@params, 'torrents=' . join(',', @$torrent_ids))  if defined($torrent_ids) && @$torrent_ids > 0;
  push(@params, $_ . '=' . $params{$_}) for keys %params;


  if ( @params > 0 )
  {
    $request->content_type('application/x-www-form-urlencoded');
    $request->content(join('&', @params));
  }

  my $response = $agent->request($request);
  if ( $response->is_success() )
  {
    my $content = $response->content();
    return decode_json($content) if $response->is_success();
  }
  die "API call failed: " . $response->code();
}

1;
