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
  return decode_json($response->content()) if $response->is_success();
  die "API call failed: " . $response->code();
}

1;
