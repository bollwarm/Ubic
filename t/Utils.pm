package t::Utils;

use strict;
use warnings;

use parent qw(Exporter);
our @EXPORT = qw( ignore_warn rebuild_tfiles xsystem xfork slurp local_ubic );

use Carp;
use Cwd;

sub import {
    my $class = shift;
    if ($ENV{PERL5LIB}) {
        $ENV{PERL5LIB} = $ENV{PERL5LIB}.":".getcwd()."/lib";
    }
    else {
        $ENV{PERL5LIB} = getcwd()."/lib";
    }

    if ($ENV{IGNORE_WARN}) {
        # parent process has set warn regex
        ignore_warn($ENV{IGNORE_WARN});
    }

    delete $ENV{$_} for grep { /^UBIC/ } %ENV; # in case user uses env to configure local ubic instance

    __PACKAGE__->export_to_level(1, @_);
}

sub rebuild_tfiles {
    system('rm -rf tfiles') and die "Can't remove tfiles";
    mkdir 'tfiles' or die "Can't create tfiles: $!";
}

sub ignore_warn {
    my $regex = shift;
    return t::Utils::WarnIgnore->new($regex);
}

sub xsystem {
    local $! = local $? = 0;
    return if system(@_) == 0;

    my @msg;
    if ($!) {
        push @msg, "error ".int($!)." '$!'";
    }
    if ($? > 0) {
        push @msg, "kill by signal ".($? & 127) if ($? & 127);
        push @msg, "core dumped" if ($? & 128);
        push @msg, "exit code ".($? >> 8) if $? >> 8;
    }
    die join ", ", @msg;
}

sub xfork {
    my $pid = fork;
    croak "fork failed: $!" unless defined $pid;
    return $pid;
}

sub slurp {
    my $file = shift;
    open my $fh, '<', $file or die "Can't open $file: $!";
    return do { local $/; <$fh> };
}

sub local_ubic {
    require Ubic;
    Ubic->set_data_dir('tfiles/ubic');
    Ubic->set_service_dir('t/service');
    Ubic->set_default_user($ENV{LOGNAME} || $ENV{USERNAME});
}

package t::Utils::WarnIgnore;

sub new {
    my ($class, $regex) = @_;
    $ENV{IGNORE_WARN} = $regex;
    my $prev_sig = $SIG{__WARN__};
    $SIG{__WARN__} = sub {
        return if $_[0] =~ $regex;
        if (ref $prev_sig and ref $prev_sig eq 'CODE') {
            $prev_sig->(@_);
        }
        else {
            warn @_;
        }
    };
    return bless { prev_sig => $prev_sig } => $class;
}

sub DESTROY {
    my $self = shift;
    $SIG{__WARN__} = $self->{prev_sig} if $self->{prev_sig};
    delete $ENV{IGNORE_WARN};
}

1;
