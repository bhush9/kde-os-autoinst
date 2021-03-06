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
use strict;
use testapi;

sub run() {
    if (get_var('SECUREBOOT')) {
        # Enable scureboot first. When in secureboot mode we expect a second
        # ISO to be attached for uefi fs1 where we can run a efi program to
        # enroll the default keys to enable secureboot.
        # In the core.pm we'll then assert that secureboot is on.
        # In first_start.pm we'll further assert that secureboot is still on.
        send_key_until_needlematch 'ovmf', 'f2';
        send_key_until_needlematch 'ovmf-select-bootmgr', 'down';
        send_key 'ret';
        send_key_until_needlematch 'ovmf-bootmgr-shell', 'up'; # up is faster
        send_key 'ret';
        assert_screen 'uefi-shell', 30;
        type_string 'fs1:';
        send_key 'ret';
        assert_screen 'uefi-shell-fs1';
        type_string 'EnrollDefaultKeys.efi';
        send_key 'ret';
        type_string 'reset';
        send_key 'ret';
        reset_consoles;
    }

    # Wait for installation bootloader. This is either isolinux for BIOS or
    # GRUB for UEFI.
    # When it is grub we need to hit enter to proceed.
    assert_screen 'bootloader', 60;
    if (match_has_tag('live-bootloader-uefi')) {
      if (testapi::get_var("INSTALLATION_OEM")) {
          send_key 'down';
          assert_screen('live-bootloader-uefi-oem');
      }
      send_key 'ret';
    }
}

sub test_flags {
    # without anything - rollback to 'lastgood' snapshot if failed
    # 'fatal' - whole test suite is in danger if this fails
    # 'milestone' - after this test succeeds, update 'lastgood'
    # 'important' - if this fails, set the overall state to 'fail'
    return { fatal => 1 };
}

1;
