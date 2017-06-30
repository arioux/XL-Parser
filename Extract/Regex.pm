package Extract::Regex;

use strict;
use Carp ();

use constant CASE_SENSITIVE => 1;
use constant IGNORE_CASE    => 0;

sub new {
  my ($class, $regex, $case) = @_;
  my $self = {};
  bless($self, $class);
  $self->regex($regex) if ($regex);
  if ($case) { $self->case($case)       }
  else       { $self->case(IGNORE_CASE) }
  return $self;
}

sub regex {
  my ($self, $regex) = @_;
  # Get
  return($self->{REGEX}) if (!$regex and $self->{REGEX});
  # Set
  eval {
    my $testLine = 'testLine';
    if ($testLine =~ /$regex/) { }
  };
  # Invalid Regex
  Carp::croak($@) if ($@);
  $self->{REGEX} = $regex;
}

sub case {
  my ($self, $case) = @_;
  # Get
  if (!$case) {
    if ($self->{CASE}) { return(CASE_SENSITIVE); }
    else               { return(IGNORE_CASE);    }
  # Set
  } else {
    Carp::croak("Value of \$case must be 0 or 1")
    if ($case != CASE_SENSITIVE and $case != IGNORE_CASE);
    $self->{CASE} = $case;
  }
}

sub extract {
  my ($self, $str) = @_;
  my $regex        = $self->regex();
  my $case         = $self->case();
  my $width        = 0;
  my $pos          = 0;
  my @results;
  my @extGroups;
  
  # Errors
  Carp::croak("No string provided")    if (!$str);
  Carp::croak("Regex not initialized") if (!$regex);
  
  # Number of capture groups
  my $nbrGroups = $self->nbrCaptureGroups();
  
  # Extract the regex
  while (($case == CASE_SENSITIVE and (@extGroups = ($str =~ /$regex/))) or
         ($case == IGNORE_CASE    and (@extGroups = ($str =~ /$regex/i)))) {
    # Regex found, no group
    return('', $str) if (!$nbrGroups);
    
    # Regex found
    my $last;
    my $res;
    foreach (@extGroups) {
      $last = $_;
      $res .= "$_\t";
    }
    $pos   = index($str,$last,$pos);
    $width = length($last);
    chop($res);
    push(@results, $res);
    
    # Remaining line
    my $widthLine = length($str);
    my $offset    = $pos+$width;
    $str          = substr($str,$offset,$widthLine-$offset);
  }
  return($str, @results);
}

sub nbrCaptureGroups {
  my $self  = shift;
  my $count = 0;
  my $nbrGroups;
  my $mask;

  # Regex not initialized
  my $regex = $self->regex();
  Carp::croak("Regex not initialized") if (!$regex);
  
  # Clean metacharacters (quoted)
  $regex =~ s/([^\\])\\\(\?/$1/g;
  $regex =~ s/([^\\])\\\)\?/$1/g;
  $regex =~ s/([^\\])\\\|\?/$1/g;
  $regex =~ s/([^\\])\\\(/$1/g;
  $regex =~ s/([^\\])\\\)/$1/g;
  $regex =~ s/([^\\])\\\|/$1/g;
  $regex =~ s/([^\\])\\\?/$1/g;
  
  # Clean other characters
  while ($regex and $count != 4) {
    $count = 0;
    my $pos = -1;
    my $el  = '';
    if ($regex =~ /(\()([^\?])/) {
      $el = $1;
      $pos = index($regex, "$el$2");
    } else { $count++; }
    if ($regex =~ /(\(\?)/) {
      my $pos2 = index($regex, $1);
      if ($pos2 < $pos or $pos == -1) {
        $pos = $pos2;
        $el  = $1;
      }
    } else { $count++; }
    if ($regex =~ /(\|)/) {
      my $pos2 = index($regex, $1);
      if ($pos2 < $pos or $pos == -1) {
        $pos = $pos2;
        $el  = $1;
      }
    } else { $count++; }
    if ($regex =~ /(\))/) {
      my $pos2 = index($regex, $1);
      if ($pos2 < $pos or $pos == -1) {
        $pos = $pos2;
        $el  = $1;
      }
    } else { $count++; }
    $mask         .= $el;
    my $widthRegex = length($regex);
    my $width      = length($el);
    my $offset     = $pos+$width;
    $regex         = substr($regex,$offset,$widthRegex-$offset);
  }
  while ($mask and $mask =~ /\(\?\|*\)/) { $mask =~ s/\(\?\|*\)//g; }
  
  # Count capture groups
  while ($mask and $mask =~ /\(\?([\(\)\|]+)\)/) {
    my $nbrAltGroups = 0;
    my @alt          = split(/\|/, $1);
    foreach my $alt (@alt) {
      $_      = $alt;
      my $nbr = s/\(//g;
      if ($nbr > $nbrAltGroups) { $nbrAltGroups = $nbr; }
    }
    $nbrGroups += $nbrAltGroups;
    $mask      =~ s/\(\?[\(\)\|]+\)//;
  }
  $mask =~ s/\|//g;
  while ($mask and $mask =~ /\(\)/) { $nbrGroups++; $mask =~ s/\(\)//; }
 
  return($nbrGroups);
}

1;

__END__

=head1 NAME

Extract::Regex - Manipulate regex

=head1 SYNOPSIS
  
 use Extract::Regex;

 my $r = Extract::Regex->new('http:\/\/([^\.]+)\.([^\.]+)\.([^\.]+)\/', 1);
 my $regex = $r->regex();
 my $case  = $r->case();
 my $nbrCaptureGroups = $r->nbrCaptureGroups();

 print "My regex is $regex\n";
 if    ($case) { print "It is case sensitive\n"; }
 else          { print "It is not case sensitive\n"; }
 if ($nbrCaptureGroups) {
   print "There are $nbrCaptureGroups capture groups\n\n";
 }

 my ($str, @results) = $r->extract('http://search.cpan.org/');
 my $nbrResults = @results;
 if ($nbrResults) {
   print "Result is :\n";
   foreach (@results) { print "$_\t"; }
   print "\n";
   if ($str) { print "\nRemaining line is : $str\n\n"; }
 } else { print "No results have been founded\n"; }

=head1 DESCRIPTION

The C<Extract::Regex> is a class providing methods to manipulate and
use Regex.

=head1 CLASS METHODS

=over 4

=item $r = Extract::Regex->new( [ $regex, $case ] );

This method constructs a new C<Extract::Regex> object and returns it. If $regex is
provided, it is tested and initialized. The value of $case must be 1 if $regex is
case sensitive or 0 if not. Default is not.

=back

=head1 OBJECT METHODS

=over 4

=item [ $regex ] = $r->regex( [$regex] );

 Get : Without parameter, this method returns the value of the regex.
 Set : If $regex is provided, this method tests and initializes the regex. It 
returns nothing if successfull or croaks otherwise.

=item [ $case ] = $r->case( [$case] );

 Get : Without parameter, this method returns 1 if case sensitive is set, 0 if not.
 Set : The value of $case must be 1 if $regex is case sensitive or 0 if not.

=item my ($str, @results) = $r->extract( $string );

This method extract matching data from $string. Without capture groups, it
returns the full line if regex is found. With capture groups, it returns the
remaining line and the list of extracted data.

=item my $nbrCaptureGroups = $r->nbrCaptureGroups;

Returns the number of capture groups '( )' in the regex.

=back

=head1 VERSION

 1.0

=head1 AUTHOR

Copyright 2009-2017 Alain Rioux

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut