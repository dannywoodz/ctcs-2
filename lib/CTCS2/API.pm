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

=back 4

=head1 AUTHOR

Danny Woods

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
  return make_api_call(shift, 'pause', \@_);
}

sub resume
{
  return make_api_call(shift, 'resume', \@_);
}

sub active
{
  return make_api_call(shift, 'active');
}

sub paused
{
  return make_api_call(shift, 'paused');
}

sub make_api_call
{
  my ($self, $call, $torrent_ids) = @_;

  my $request = HTTP::Request->new('POST', sprintf(URL_TEMPLATE, $self->{host}, $self->{port}, $call));
  my $agent   = LWP::UserAgent->new();

  if ( defined($torrent_ids) && @$torrent_ids > 0 )
  {
    $request->content_type('application/x-www-form-urlencoded');
    $request->content('torrents=' . join(',', @$torrent_ids));
  }

  my $response = $agent->request($request);
  return decode_json($response->content()) if $response->is_success();
  die "API call failed: " . $response->code();
}

1;
