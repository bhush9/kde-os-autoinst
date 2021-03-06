# Copyright (C) 2017 Harald Sitter <sitter@kde.org>
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

use base "basetest";
use testapi;

# Core test to run for all install cases. Asserts common stuff.
sub run {
    # Eventually we should end up in sddm
    # If we find grub instead we'll throw a tantrum. With only one OS installed
    # grub should be hidden by default unless the previous shutdown wasn't clean
    # none of which should be the case on first start!
    # NB: this is 10m because we do not also wait for grub, so this timeout
    #   entails: shutdown of the live session + uefi reinit +
    #            grub (possibly with) + actual boot + start of sddm.
    #   with tests running on drax presently this can easily exceed 5m
    #   (which would be my otherwise preferred value) as drax may be busy
    #   doing other things as well that slow the test down.
    assert_screen ['sddm', 'grub'], 60 * 10;
    if (match_has_tag('grub')) {
        die 'Grub should not be visible by defualt but was detected';
    }

    select_console 'log-console';

    # Assert that we have no preinstalled pool lingering around on the installed
    # rootfs. preinstalled-pool comes from our livecd-rootfs-neon fork and
    # contains bootloaders for offline install. This should be removed before
    # installation is finalized
    if (script_run('grep -r preinstalled-pool /etc/apt/') == 0) {
        die '/var/lib/preinstalled-pool is in /etc/apt/* after install';
    }
    if (script_run('[ -e /var/lib/preinstalled-pool ]') == 0) {
        die '/var/lib/preinstalled-pool exist after install';
    }

    # Make sure this system is bootable throughout all use cases by ensuring
    # our loader is used as fallback loader in EFI\boot\bootx64.efi
    assert_script_run 'wget ' . data_url('uefi_boot.rb'),  16;
    assert_script_sudo 'ruby uefi_boot.rb', 16;

    assert_script_run 'wget ' . data_url('enable_qdebug.rb'),  16;
    assert_script_run 'ruby enable_qdebug.rb', 16;

    assert_script_run 'wget ' . data_url('snapd_disable.rb'),  16;
    assert_script_sudo 'ruby snapd_disable.rb', 16;

    if (get_var('OPENQA_IN_CLOUD')) {
        assert_script_run 'wget ' . data_url('apt_mirror.rb'),  16;
        assert_script_sudo 'ruby apt_mirror.rb', 16;
    }

    if (get_var('SECUREBOOT')) {
        assert_script_sudo 'apt install -y mokutil', 60;
        assert_script_sudo 'mokutil --sb-state', 16;
        assert_screen 'mokutil-sb-on';
    }

    # Testing grub is a bit tricky because we first need to make sure it is
    # visible. To do that we'll run a fairly broad unhide script
    assert_script_run 'wget ' . data_url('grub_toggle_hide.rb'),  16;
    assert_script_sudo 'ruby grub_toggle_hide.rb', 16;

    script_sudo 'reboot', 0;
    reset_consoles;

    # Now grub ought to be appearing.
    assert_screen "grub", 60;
    send_key 'ret'; # start first entry

    # Once we are on sddm, hide grub again to speed up regular boots.
    assert_screen 'sddm', 60 * 10;
    select_console 'log-console';
    assert_script_sudo 'ruby grub_toggle_hide.rb', 16;

    script_sudo 'shutdown now', 0;
    assert_shutdown;
}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return { milestone => 1 };
}

1;
