# Copyright (C) 2018 Harald Sitter <sitter@kde.org>
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

use base "basetest_neon";
use testapi;

sub kscreenlocker_disable {
    x11_start_program 'kcmshell5 screenlocker' ;
    assert_screen 'kcm-screenlocker';
    if (match_has_tag 'kcm-screenlocker-enabled') {
        assert_and_click 'kcm-screenlocker-disable';
    }
    assert_screen 'kcm-screenlocker-disabled';
    assert_and_click 'kcm-ok';
}

sub run {
    my ($self) = @_;
    $self->boot;

    select_console 'log-console';
    {
        # Manually downgrade xorg from HWE. There is a bug where xorg-hwe is
        # not being properly migrated.
        # https://bugs.launchpad.net/bugs/1749688
        assert_script_sudo 'apt update', 60;
        assert_script_sudo 'apt -y install xserver-xorg', 60 * 5;
        record_soft_failure 'Downgrading xorg-hwe to xorg to enable upgrade';

        assert_script_run 'wget ' . data_url('upgrade_bionic.rb'),  16;
        assert_script_sudo 'ruby upgrade_bionic.rb', 60;
    }
    select_console 'x11';

    # Disable screen locker, this is gonna take a while.
    kscreenlocker_disable;

    # x11_start_program 'kubuntu-devel-release-upgrade';
    x11_start_program 'konsole';
    assert_screen 'konsole';
    type_string 'kubuntu-devel-release-upgrade';
    send_key 'ret';

    assert_screen 'kdesudo';
    type_password $testapi::password;
    send_key 'ret';

    assert_screen 'ubuntu-upgrade-fetcher-notes';
    assert_and_click 'ubuntu-upgrade-fetcher-notes';

    assert_screen 'ubuntu-upgrade';
    # ... preparation happens ...
    assert_and_click 'ubuntu-upgrade-start', 'left', 60 * 5;
    assert_and_click 'ubuntu-upgrade-remove', 'left', 60 * 15;

    assert_screen 'ubuntu-upgrade-restart', 'left', 60 * 5;

    # upload logs in case something went wrong!
    select_console 'log-console';
    {
        assert_script_sudo 'tar -cJf /tmp/dist-upgrade.tar.xz /var/log/dist-upgrade/';
        upload_logs '/tmp/dist-upgrade.tar.xz';
    }
    select_console 'x11';

    assert_and_click 'ubuntu-upgrade-restart';

    reset_consoles;
    $self->boot_to_dm;
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;

    select_console 'log-console';

    assert_script_run 'journalctl --no-pager -b 0 > /tmp/journal.txt';
    upload_logs '/tmp/journal.txt';

    upload_logs '/var/log/dpkg.log';
    upload_logs '/var/log/apt/term.log';
    upload_logs '/var/log/apt/history.log';
}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return { important => 1, fatal => 1 };
}

1;
