# SPDX-FileCopyrightText: 2021 Esther Bergter <esther.bergter@vipcomag.de>
#
# SPDX-License-Identifier: GPL-3.0-or-later

"""
Copyright (C) 2021 Esther Bergter

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software Foundation,
   Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301
"""
#
# configmount.pxi
# mount alternate filesystem
#
# Author: Esther Bergter
#
# Version 1.0


cdef str str_altmount = ''
partition_number = 0      # partition_number not initialized yet

def checkmount_alternate(type):
    """ mount alternate partition if type=True, else unmount it """
    get_alternate_mountname()
    if os.path.exists(alternate_partition):
        if os.path.ismount(alternate_partition):
            if type == True:
                log.info("alternate partition already mounted, ok")
                return True
            else:
                return mysystemcall(["umount", alternate_partition], False)
        else:
            if type == False:
                log.info("alternate partition not mounted, ok")
                return True
            # else mount later
    else:
        if type == True:
            os.mkdir(alternate_partition)
        else:
            log.info("no alternate partition, ok")
            return True
    # reached only if type==True
    if not issel4():
        debug("mount skipped (not on sel4)")
        return True
    if len(str_altmount) < 4:
        log.error("mount_alternate: invalid device %s" % (str_altmount,))
        log.error("mount_alternate failed\n")
        return False
    return mysystemcall(["mount", str_altmount, alternate_partition], False)

# group_log and group_update
def get_alternate_mountname():
    """ build device with alternate partition number """
    global str_altmount

    if len(str_altmount) > 0:
        log.info(f'alternate device {str_altmount}')
        return
    if partition_number == 0: # not initialized yet
        get_partition()
    if partition_number > 0 and partition_number < 3:
        alt_number = 3 - partition_number
    else:
        alt_number = -1
    if alt_number > 0:
        str_altmount = mountbase + str(alt_number)
        log.info("alternate device %s" % (str_altmount,))
    else:
        if issel4():
            log.error("no alternate device, invalid partition_number %d" %(partition_number,))
        else:
            log.info("no alternate device (not on sel4)" )

def get_partition():
    ''' read partition number from device-tree '''
    global partition_number

    try:
        with open(partition_path, 'r') as f:
            for l in f.readlines():
                str_partition = l.strip().split('\x00')
                break
            partition_number = int(str_partition[0])
    except:
        if issel4():
            log.error("cannot read partition %s" % partition_path)
        partition_number = -1
    finally:
        log.info("partition %d" % (partition_number))

def mysystemcall(args, wantprogress):
    """ systemcall per subprocess, output to log and updateprogress """
    try:
        exception_occurred = 0
        output = subprocess.check_output(args, stderr=subprocess.STDOUT, encoding="utf8")
    except CalledProcessError as e:
        exception_occurred = 1
        output = e.output
        log.error("%s subprocess returned, exc_o= %d, output %s" %(args[0], exception_occurred, output ))
    finally:
        if not exception_occurred:
            if output and len(output):
                out = output
            else:
                out = "%s completed" % (args[0],)
        else:
            out = output
        log.info(out)
        if wantprogress:
            out += "\n"
            append_progress(out)
    if exception_occurred:
        return False
    else:
        return True
# m_ysystemcall
