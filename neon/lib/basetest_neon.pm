# Copyright (C) 2017-2018 Harald Sitter <sitter@kde.org>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of
# the License or (at your option) version 3 or any later version
# accepted by the membership of KDE e.V. (or its successor approved
# by the membership of KDE e.V.), which shall act as a proxy
# defined in Section 14 of version 3 of the license.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

package basetest_neon;
use base 'basetest';

use testapi;
use strict;

sub new {
    my ($class, $args) = @_;
    my $self = $class->SUPER::new($args);
    # TODO: this maybe should be global as within a test series we still only
    #   use the same VM and disk, so setup actually only needs to happen once
    #   in an entire os-autoinst run.
    $self->{boot_setup_ran} = 0;
    return $self;
}

sub post_fail_hook {
    if (check_screen('drkonqi-notification', 4)) {
        assert_and_click('drkonqi-notification');
        record_soft_failure 'not implemented drkonqi opening';
    }

    select_console 'log-console';

    # The next uploads are largely failok since we want to get as many logs
    # as possible evne if some are missing.
    upload_logs '/home/'.$testapi::username.'/.cache/xsession-errors', failok => 1;
    upload_logs '/home/'.$testapi::username.'/.cache/sddm/xsession-errors', failok => 1;
    upload_logs '/home/'.$testapi::username.'/.xsession-errors', failok => 1;

    upload_logs '/home/'.$testapi::username.'/.local/share/sddm/wayland-session.log', failok => 1;

    script_run 'journalctl --no-pager -b 0 > /tmp/journal.txt';
    upload_logs '/tmp/journal.txt', failok => 1;

    script_run 'coredumpctl info > /tmp/dumps.txt';
    upload_logs '/tmp/dumps.txt', failok => 1;

    return 1;
}

sub login {
    my ($self) = @_;
    # Short wait, we should be close to sddm if we this gets called.
    assert_screen 'sddm', 120;
    $self->maybe_login;
}

sub maybe_login {
    # Short wait, we should be close to sddm if we this gets called.
    if (check_screen 'sddm', 16) {
        type_password $testapi::password;
        send_key 'ret';
        wait_still_screen;
    }
}

sub boot_to_dm {
    my ($self, %args) = @_;
    $args{run_setup} //= 1;

    # Grub in user edition is broken as of Jan 2018 and doesn't match our needle
    # because it is shittyly themed. As we do not entirely care about this in
    # application tests we'll simply ignore it by checking for either grub or
    # sddm. Due to auto time out we'll eventually end up at sddm even if
    # we do not explicitly hit 'ret'.
    assert_screen [qw(grub sddm)], 60 * 3;
    if (match_has_tag('grub')) {
        send_key 'ret';
        assert_screen 'sddm', 60 * 2;
    }
    # else sddm, nothing to do

    if ($args{run_setup} && !$self->{boot_setup_ran}) {
        select_console 'log-console';
        {
            assert_script_run 'wget ' . data_url('basetest_setup.rb'),  60;
            assert_script_sudo 'ruby basetest_setup.rb', 60;

            # FIXME: copy pasta from install core.pm
            if (get_var('OPENQA_APT_UPGRADE')) {
                assert_script_sudo 'apt update',  2 * 60;
                my $pkgs = get_var('OPENQA_APT_UPGRADE');
                if ($pkgs eq "") {
                    $pkgs = "dist-upgrade";
                } else {
                    $pkgs = "install " . $pkgs;
                }
                assert_script_sudo 'DEBIAN_FRONTEND=noninteractive apt -y ' . $pkgs, 30 * 60;
            }
        }
        select_console 'x11';
        $self->{boot_setup_ran} = 1;
    }
}

# Waits for system to boot to desktop.
sub boot {
    my ($self, $args) = @_;

    $self->boot_to_dm;

    type_password $testapi::password;
    send_key 'ret';

    wait_still_screen;
}

sub enable_snapd {
    my ($self, $args) = @_;
    select_console 'log-console';
    assert_script_sudo 'systemctl enable --now snapd.service';
    assert_script_sudo 'snap switch --candidate kde-frameworks-5',;
    assert_script_sudo 'snap refresh', 30 * 60;
    select_console 'x11';
}

1;
