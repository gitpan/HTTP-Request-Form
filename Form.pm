package HTTP::Request::Form;

use strict;
use vars qw($VERSION);
use URI::URL;
use HTTP::Request::Common;

$VERSION = "0.3";

sub new {
   my ($class, $form, $base, $debug) = @_;
   my @allfields;
   my @fields;
   my %fieldvals;
   my @buttons;
   my %buttonvals;
   my %selections;

   $form->traverse(
      sub {
      my ($self, $start, $depth) = @_;
      if (ref $self) {
         my $tag = $self->tag;
         if ($tag eq 'input') {
            my $type = $self->attr('type');
            if ($type eq 'hidden') {
               my $name = $self->attr('name');
               my $value = $self->attr('value');
               push @allfields, $name;
               $fieldvals{$name} = $value;
            } elsif ($type eq 'submit') {
               my $name = $self->attr('name');
               my $value = $self->attr('value');
               if (defined($name)) {
                  if (!defined($buttonvals{$name})) {
                      push @buttons, $name;
                      $buttonvals{$name} = [$value];
                  } else {
                      push @{$buttonvals{$name}}, $value;
                  }
               }
            } else {
               my $name = $self->attr('name');
               my $value = $self->attr('value');
               push @allfields, $name;
               push @fields, $name;
               $fieldvals{$name} = $value;
            }
         } elsif (($tag eq 'select') && $start) {
            my $name = $self->attr('name');
            push @allfields, $name;
            push @fields, $name;
            foreach my $o (@{$self->content}) {
               if (ref $o) {
                  my $tag = $o->tag;
                  if ($tag eq 'option') {
                     if ($o->attr('selected')) {
                        $fieldvals{$name} = $o->attr('value');
                     }
                     if (!defined($selections{$name})) {
                        $selections{$name} = [$o->attr('value')];
                     } else {
                        push @{$selections{$name}}, $o->attr('value');
                     }
                  }
               }
            }
         }
      }
      1;
      }, 0
   );

   my $self = {};
   $self->{'debug'} = $debug;
   $self->{'method'} = $form->attr('method');
   $self->{'link'} = $form->attr('action');
   $self->{'base'} = $base;
   $self->{'allfields'} = \@allfields;
   $self->{'fields'} = \@fields;
   $self->{'fieldvals'} = \%fieldvals;
   $self->{'buttons'} = \@buttons;
   $self->{'buttonvals'} = \%buttonvals;
   $self->{'selections'} = \%selections;
   bless $self, $class;
}

sub fields {
   my $self = shift;
   return @{$self->{'fields'}};
}

sub allfields {
   my $self = shift;
   return @{$self->{'allfields'}};
}

sub base {
   my $self = shift;
   return $self->{'base'};
}

sub method {
   my $self = shift;
   return $self->{'method'};
}

sub link {
   my $self = shift;
   return $self->{'link'};
}

sub field {
   my ($self, $name, $value) = @_;
   if (defined($value)) {
      $self->{'fieldvals'}->{$name} = $value;
   } else {
      return $self->{'fieldvals'}->{$name};
   }
}

sub field_selection {
   my ($self, $name) = @_;
   return $self->{'selections'}->{$name};
}

sub is_selection {
   my ($self, $name) = @_;
   if (defined($self->field_selection($name))) {
      return 1;
   } else {
      return undef;
   }
}

sub buttons {
   my $self = shift;
   return @{$self->{'buttons'}};
}

sub button {
   my ($self, $button, $value) = @_;
   if (defined($value)) {
      $self->{'buttonvals'}->{$button} = $value;
   } else {
      return $self->{'buttonvals'}->{$button};
   }
}

sub button_exists {
   my ($self, $button) = @_;
   if (defined($self->button($button))) {
      return 1;
   } else {
      return undef;
   }
}

sub press {
   my ($self, $button, $bnum) = @_;
   my @array = ();
   foreach my $i ($self->allfields) {
      push @array, $i;
      push @array, $self->field($i);
   }
   if (defined($button)) {
      push @array, $button;
      if (defined($bnum)) {
         push @array, @{$self->button($button)}[$bnum];
      } else {
         push @array, @{$self->button($button)}[0];
      }
   }
   my $url = url $self->link;
   if (defined($self->base)) {
      $url = $url->abs($self->base);
   }
   if ($self->{'debug'}) {
      print $self->method, " ", $self->link, " ", join(' - ', @array), "\n";
   }
   if (uc($self->method) eq "POST") {
      return POST $url, \@array;
   } elsif (uc($self->method) eq "GET") {
      return GET $url, \@array;
   }
}

sub dump {
   my $self = shift;
   print "FORM METHOD=", $self->method, "\n     ACTION=", $self->link, "\n     BASE=", $self->base, "\n";
   foreach my $i ($self->allfields) {
      if (defined($self->field($i))) {
         print "FIELD $i=", $self->field($i), "\n";
      } else {
         print "FIELD $i\n";
      }
      if ($self->is_selection($i)) {
         print "      [", join(", ", @{$self->field_selection($i)}), "]\n";
      }
   }
   foreach my $i ($self->buttons) {
      if (defined($self->button($i))) {
         print "BUTTON $i=[", join(", ", @{$self->button($i)}), "]\n";
      } else {
         print "BUTTON $i\n";
      }
   }
   print "\n";
}

1;

__END__

=head1 NAME

HTTP::Request::Form - Construct HTTP::Request objects for form processing

=head1 SYNOPSIS

  use HTTP::Request::Form;
  use HTML::TreeBuilder;
  use URI::URL;

  $ua = LWP::UserAgent->new;
  $url = url 'http://www.sn.no/';
  $res = $ua->request(GET $url);
  $p = HTML::TreeBuilder->new;
  foreach $i (@{$p->extract_links(qw(form))}) {
     $f = HTTP::Request::Form->new($i, $url);
     $f->field("user", "hugo");
     $f->field("password", "duddi");
     $ua->request($f->press("Send"));
  }
  $p->delete();

=head1 DESCRIPTION

This is an extension of the HTTP::Request suite. It allows easy processing
of forms in a user agent by filling out fields, querying fields, selections
and buttons and pressing buttons. It uses HTML::TreeBuilder generated parse
triees of documents (especially the forms parts extracted with extract_links)
and generates it's own internal representation of forms from which it then
generates the request objects to process the form application.

=head1 CLASS METHODS

=over 4

=item new($form [, $base [, $debug]])

The new-method constructs a new form processor. It get's an HTML::Element
object that contains a form as the single parameter. If an base-url is given
as an additional parameter, this is used to make the form-url absolute in
regard to the given URL.

If debugging is true, the following functions will be a bit "talky" on stdio.

=back

=head1 INSTANCE METHODS

=over 4

=item base()

This returns the parameter $base to the "new" constructor.

=item link()

This returns the action attribute of the original form structure. This value
is cached within the form processor, so you can safely delete the form
structure after you created the form processor.

=item method()

This returns the method attribute of the original form structure. This value
is cached within the form processor, so you can safely delete the form
structure as soon as you created the form processor.

=item fields()

This method delivers a list of fieldnames that are of "open" type. This
excludes the "hidden" and "submit" elements, because they are already filled
with a value (and as such declared as "closed") or as in the case of "submit"
are buttons, of which only one must be used.

=item allfields()

This delivers a list of all fieldnames in the order as they occured in the
form-source excluding the submit fields.

=item field($name [, $value])

This method retrieves or sets a field-value. The field is identified by
it's name. You have to be sure that you only put a allowed value into the
field.

=item is_selection($name)

This tests if a field is a selection or an input.

=item field_selection($name)

This delivers the array of the options of a selection. The element that is
marked with selected in the source is given as the default value.

=item buttons()

This delivers a list of all defined and named buttons of a form.

=item button($button [, $value])

This gets or sets the value of a button. Normally only getting a button value
is needed. The value of a button is a reference to an array of values (because
a button can exist multiple times).

=item button_exists($button)

This gives true if the named button exists, false (undef) otherwise.

=item press([$name [, $number]])

This method creates a HTTP::Request object (via HTTP::Request::Common) that
sends the formdata to the server with the requested method. If you give a
button-name, that button is used. If you give no button name, it assumes a
button without a name and just leaves out this last parameter. If the number
of the button is given, that button value is delivered. If the number is not
given, 0 (the first button of this name) is assumed.

=item dump()

This method dumps the form-data on stdio for debugging purpose.

=back

=head1 SEE ALSO

L<HTTP::Request>, L<HTTP::Request::Common>, L<LWP::UserAgent>,
L<HTML::Element>, L<URI::URL>

=head1 INSTALLATION

  perl Makefile.PL
  make install

=head1 REQUIRES

  Perl version 5.004 or later

  HTTP::Request::Common
  HTML::TreeBuilder
  LWP::UserAgent

=head1 VERSION

HTTP::Request::Form version 0.2, July 15th, 1998

=head1 BUGS

Only a subset of all possible form elements are currently supported. The list
of supported tags as of this version includes:

  INPUT
  INPUT/HIDDEN
  INPUT/SUBMIT
  SELECT
  OPTION

There currently is no special code to help with radio buttons or checkboxes.
Although these can easily be used with the standard INPUT handler, it would
be better to give a simpler interface to them.

=head1 COPYRIGHT

Copyright 1998, Georg Bauer <Georg_Bauer@muensterland.org>

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

