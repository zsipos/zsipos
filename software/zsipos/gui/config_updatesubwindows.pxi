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
# config_updatesubwindows.pxi
#
# Author: Esther Bergter
#
# Version 1.0

# WinUpdateInfo, WinUpdateSure, WinUpdateProgress, WinEditHex

cdef Fl_Text_Buffer* updateInfoBuffer
cdef Fl_Text_Buffer* updateProgressBuffer

cdef str str_updateVersion = ''       # aus update.txt
cdef str str_updateFilename = ''      # aus update.txt
cdef str str_update_hexdigest = ''    # checksum des downloads

subwindows_initialized = False

def subwindows_init():
    # WinUpdateInfo
    global updateInfoBuffer
    global updateProgressBuffer
    global subwindows_initialized

    ui = configui

    updateInfoBuffer = new Fl_Text_Buffer()
    ui.txt_updateinfo.buffer(updateInfoBuffer)
    ui.txt_updateinfo.wrap_mode(3, 0) # 3=WRAP_AT_BOUNDS
    ui.txt_updateinfo.scrollbar_width(20)
    ui.btn_updateinfo_back.callback(on_btn_updateinfo_back, NULL)
    ui.btn_updateinfo_ok.callback(on_btn_updateinfo_ok, NULL)
    # WinUpdateProgress
    updateProgressBuffer = new Fl_Text_Buffer()
    updateProgressBuffer.text("")
    ui.txt_updateprogress.buffer(updateProgressBuffer)
    ui.txt_updateprogress.wrap_mode(3, 0) # 3=WRAP_AT_BOUNDS
    ui.txt_updateprogress.scrollbar_width(20)
    ui.btn_updateprogress_cancel.callback(on_btn_updateprogress_cancel, NULL)
    ui.btn_updateprogress_reboot.callback(on_btn_updateprogress_reboot, NULL)
    # WinEditHex
    ui.btn_hex_back.callback(on_btn_hex_ignore, NULL)
    ui.btn_hex_cancel.callback(on_btn_hex_cancel, NULL)
    ui.btn_hex_ok.callback(on_btn_hex_ok, NULL)
    ui.btn_hex_warn.callback(on_btn_hex_warn, NULL)
    subwindows_initialized = True

# winUpdateInfo
cdef void on_btn_updateinfo_back(Fl_Widget* widget, void *data) with gil:
    configui.winUpdateInfo.hide()

cdef void on_btn_updateinfo_ok(Fl_Widget* widget, void *data) with gil:
    configui.winUpdateInfo.hide()
    if config_has_changed():
        restart_type = 'update'
        cfg_cleanup()
        info = "config has changed, %s requested" % (restart_type,)
        show_save(info, restart_type)
    else:
        show_sure('Are you sure to update now?', 'Update')

# winUpdateProgress
cdef void on_btn_updateprogress_cancel(Fl_Widget* widget, void *data) with gil:
    global user_hit_cancel_button
    debug("user hit cancel")
    checkmount_alternate(False)
    if UpdateFailed or UpdateHalted:
        configui.winUpdateProgress.hide()
    else:
        user_hit_cancel_button = True
        configui.btn_updateprogress_cancel.deactivate()

cdef void on_btn_updateprogress_reboot(Fl_Widget* widget, void *data) with gil:
    checkmount_alternate(True)
    write_alternateversion_count()
    do_restart('reboot')


# winEditHex
cdef void on_btn_hex_ok(Fl_Widget* widget, void *data) with gil:
    global hexdigest_matches

    if compare_hexdigest():
        hexdigest_matches = True
        configui.winEditHex.hide()
        to_updateprogress(str_hexdigest_matches)
        do_update2()
    else:
        hexdigest_matches = False
        configui.keyboardgroup_hex_func.hide()
        configui.keyboardgroup_hex.hide()
        configui.btn_hex_warn.show()

cdef void on_btn_hex_ignore(Fl_Widget* widget, void *data) with gil:
    global hexdigest_matches

    hexdigest_matches = True
    configui.winEditHex.hide()
    to_updateprogress(str_hexdigest_ignored)
    do_update2()

cdef void on_btn_hex_cancel(Fl_Widget* widget, void *data) with gil:
    global hexdigest_matches
    global UpdateFailed

    hexdigest_matches = False
    UpdateFailed = True
    configui.winEditHex.hide()
    to_updateprogress(str_hexdigest_canceled)
    to_updateprogress(str_update_failed)

cdef void on_btn_hex_warn(Fl_Widget* widget, void *data) with gil:
    configui.keyboardgroup_hex_func.show()
    configui.keyboardgroup_hex.show()
    configui.btn_hex_warn.hide()

# python
def append_progress(out):
    """ append text and show """
    updateProgressBuffer.append(out)
    lines = configui.txt_updateprogress.count_lines(0, updateProgressBuffer.length(), False)
    configui.txt_updateprogress.scroll(lines, 0)
    configui.winUpdateProgress.flush()
    configui.winUpdateProgress.show()

def append_updateinfo(out):
    """ append text and show """
    updateInfoBuffer.append(out)
    lines = configui.txt_updateinfo.count_lines(0, updateInfoBuffer.length(), False)
    configui.txt_updateinfo.scroll(lines, 0)
    configui.winUpdateInfo.flush()
    configui.winUpdateInfo.show()

def check_update(ret):
    """ return true if update can continue, else false """
    global UpdateHalted
    global UpdateFailed

    Fl.check()
    if UpdateHalted:
        log.info("check_update found UpdateHalted")
        return False
    if UpdateFailed:
        log.info("check_update found UpdateFailed")
        return False
    elif user_hit_cancel_button:
        log.info("check_update found user_hit_cancel_button")
        to_updateprogress(str_update_canceled)
        UpdateHalted = True
        configui.winUpdateProgress.hide()
        return False
    elif not ret:
        log.info("check_update found ret not ok")
        to_updateprogress(str_update_failed)
        UpdateFailed = True
        configui.btn_updateprogress_cancel.activate()
        return False
    else:
        debug("check_update ok")
        return True

def compare_hexdigest():
    """ compare entered string with str_update_hexdigest """
    mystring = get_hexbuf()
    debug(mystring)
    if mystring == str_update_hexdigest.upper():
        return True
    else:
        return False

def copy_configs():
    """ copy files in config-list to alternate filesystem """
    if os.path.exists(copylist_path):
        if checkmount_alternate(True):
            to_updateprogress(str_copy_config)
            with open(copylist_path, 'r') as f:
                for l in f.readlines():
                    source = l.strip()
                    if '*' in source:
                        for fn in glob.glob(source):
                            copy_file(fn)
                    else:
                        copy_file(source)
            to_updateprogress(str_copy_config_done)
            return True
        else:
            err_to_updateprogress('copy_configs: mount alternate failed')
            return False
    else:
        #log.error("copy_configs: %s not found" % (copylist_path,))
        err_to_updateprogress("copy_configs: %s not found\n" % (copylist_path,))
        return False

def copy_file(source):
    """ copy source to alternate_partition, generate dirs as needed """
    #to_updateprogress("copy_file source %s\n" % (source, ))
    if os.path.exists(source):
        dest = altversfilename(source)
        log.info("copy_file dest %s" % (dest, ))
        (head, tail) = os.path.split(dest)
        if not os.path.isdir(head):
            os.mkdir(head)
        try:
            shutil.copy2(source,dest,follow_symlinks=False)
        except PermissionError:
            if issel4():
                update_exception()
            log.error("cannot copy(%s,%s), permission denied" % (source, dest))
        except:
            if issel4():
                raise

def do_update1():
    """ download tar, calc checksum with UpdateProgress Win """
    global user_hit_cancel_button
    global UpdateHalted
    global UpdateFailed

    user_hit_cancel_button = False
    UpdateHalted = False
    UpdateFailed = False
    configui.btn_updateprogress_reboot.deactivate()
    configui.btn_updateprogress_cancel.activate()
    configui.winUpdateProgress.show()
    configui.winUpdateProgress.wait_for_expose()
    updateProgressBuffer.text(str_update_started)
    configui.winUpdateProgress.flush()
    try:
        ret = download_update()
        if check_update(ret):
            show_keyboardhex()
    except:
        update_exception()
        update_failed()

def do_update2():
    """ mkfs, unpack tar, copy configs """
    global UpdateHalted

    try:
        if check_update(hexdigest_matches):
            ret = untar_update() # with mkfs
            debug("do_update2: untar_update() returned %s" % ("True" if ret else "False"))
        if check_update(ret):
            ret = copy_configs()
            debug("do_update2: copy_configs() returned %s" % ("True" if ret else "False"))
        if check_update(ret):
            ret = write_alternateversion_text()
            debug("do_update2: write_alternateversion_text() returned %s" % ("True" if ret else "False"))
        # kein umount! muss versioncount noch schreiben
        if check_update(ret):
            to_updateprogress(str_update_completed)
            to_updateprogress(str_update_reboot_information)
            UpdateHalted = True     # update finished
            configui.btn_updateprogress_reboot.activate()
    except:
        update_exception()
        update_failed()

def download_update():
    ''' download update to fixed path '''
    global str_update_hexdigest

    cdef long dl
    cdef int done
    cdef int olddone
    cdef int mypos
    cdef int lastpos
    cdef long total_length

    if len(str_updateFilename) > 0:
        link = os.path.join(cfdict[consts.UPDATEURI], str_updateFilename)
        if not os.path.exists(updatetar_path):
            os.mkdir(updatetar_path)
        dest = os.path.join(updatetar_path, str_updateFilename)
    else:
        err_to_updateprogress("download filename not found\n")
        return False

    try:
        with open(dest, "wb") as f: # wb for binary data
            to_updateprogress(str_download_started)
            log.info("downloading %s to %s" % (link, dest))
            response = requests.get(link, stream=True)
            status_code = int(response.status_code)
            if status_code < 200 or status_code > 229:
                err_to_updateprogress("download %s failed, status %d\n" % (link, status_code))
                return False
            sha256 = hashlib.sha256()
            sha256.update(update_binary) # add update.txt
            total = response.headers.get('content-length')
            if total is None: # no content-length header
                f.write(response.content)
                sha256.update(response.content)
            else:
                chunk_size = 1024 * 64
                dl = 0
                olddone = -1
                total_length = int(total)
                mypos = updateProgressBuffer.length()
                lastpos = mypos+1
                for data in response.iter_content(chunk_size=chunk_size): # sel4ip max chunk
                    Fl.check()
                    if user_hit_cancel_button:
                        debug("download_update_canceled")
                        break
                    dl += len(data)
                    f.write(data)
                    sha256.update(data)
                    done = 100 * dl // total_length
                    if done > olddone:
                        updateProgressBuffer.replace(mypos, lastpos, "%d%% " % (done,))
                        configui.winUpdateProgress.flush()
                        lastpos = updateProgressBuffer.length()
                        olddone = done
            if user_hit_cancel_button:
                to_updateprogress("\n%s" % (str_download_canceled,))
                return False
            elif check_update(True):
                str_update_hexdigest = sha256.hexdigest()
                debug(str_update_hexdigest)
                to_updateprogress(str_download_completed)
                return True
            else:
                return False
    except:
        update_exception()
        err_to_updateprogress(str_download_failed)
        return False
# download_update

def err_to_updateprogress(mytext):
    """ append to progress buffer and to log.error """
    err_to_win(mytext, 'progress')

def mkfs(devname):
    if not issel4():
        debug("mkfs skipped (not on sel4)")
        if os.path.exists(alternate_partition):
            debug("clean alternate")
            return mysystemcall(["rm", "-rf", alternate_partition], False)
        else:
            return True
    if len(devname) < 4:
        err_to_updateprogress("mkfs: invalid devname %s\n" % (devname,))
        return False
    if checkmount_alternate(False): # umount
        return mysystemcall(["mkfs.ext4", devname], False) # True -> updateprogress
    else:
        log.error("mkfs: cannot umount alternate partition")
        return False

def show_updateinfo(out):
    """ show help window with label and display out """
    if not subwindows_initialized:
        subwindows_init()
    debug(f'show_updateinfo({out})')
    updateInfoBuffer.text(out)
    lines = configui.txt_updateinfo.count_lines(0, updateInfoBuffer.length(), True)
    configui.txt_updateinfo.scroll(lines, 0)
    configui.winUpdateInfo.wait_for_expose()
    configui.winUpdateInfo.flush()
    configui.winUpdateInfo.show()

def to_updateprogress(mytext):
    """ append to progress buffer and to log.info """
    if mytext.endswith('\n'):
        log.info(mytext[:-1])
    else:
        log.info(mytext)
    if stable:
        append_progress(mytext)

def untar_with_progress(filename):
    cdef int  chunk_size
    cdef long total
    cdef long processed
    cdef int  percent
    cdef int  last_percent
    cdef int  mypos
    cdef int  lastpos

    to_updateprogress(str_unpack_started)
    chunk_size = 1024 * 64
    total = os.path.getsize(filename)
    processed = 0
    last_percent = -1
    mypos = updateProgressBuffer.length()
    lastpos = mypos+1
    try:
        proc = subprocess.Popen("gzip -d -c | tar xf -", shell=True, stdin=subprocess.PIPE)
        with open(filename, "rb") as f:
            for chunk in iter(lambda: f.read(chunk_size), b""):
                Fl.check()
                if user_hit_cancel_button:
                    proc.stdin.close()
                    proc.wait()
                    to_updateprogress(str_unpack_canceled)
                    return False
                proc.stdin.write(chunk)
                processed += len(chunk)
                percent = 100 * processed // total
                if (percent > last_percent):
                    updateProgressBuffer.replace(mypos, lastpos, "%d%% " % (percent,))
                    configui.winUpdateProgress.flush()
                    lastpos = updateProgressBuffer.length()
                    last_percent = percent
        proc.stdin.close()
        ret = proc.wait()
        if ret == 0:
            to_updateprogress(str_unpack_completed)
            return True
        else:
            err_to_updateprogress(str_unpack_failed)
            return False
    except:
        update_exception()
        err_to_updateprogress(str_unpack_failed)
        return False
# u_ntar_with_progress

def untar_update():
    """ mkfs and expand update to alternate partition """
    if check_update(True):
        configui.btn_updateprogress_cancel.deactivate()
        to_updateprogress("preparing filesystem, please wait\n")
        ret = mkfs(str_altmount) # start with clean filesystem
        if ret:
            to_updateprogress("filesystem done.\n")
        configui.btn_updateprogress_cancel.activate()
    if check_update(ret):
        ret = checkmount_alternate(True) # mount alternate
    if check_update(ret):
        localpath=os.getcwd()
        fn = os.path.join(localpath, updatetar_path, str_updateFilename)
        os.chdir(alternate_partition)
        ret = untar_with_progress(fn)
        os.chdir(localpath)
        debug("unpack returned %d" % (ret,))
        return ret

def update_exception():
    global UpdateFailed
    global UpdateHalted

    logerrorexception('progress')
    UpdateFailed = True
    UpdateHalted = True
    debug("UpdateFailed, UpdateHalted")

def update_failed():
    """ show failure, user must press cancel """
    to_updateprogress(str_update_failed)
    configui.btn_updateprogress_cancel.activate()

def write_alternateversion_text():
    """ write alternate  version.txt """
    if checkmount_alternate(True):
        fn = altversfilename(versiontext_path)
        with open(fn, "w") as f:
           print(str_updateVersion, file=f)
        configui.out_alternate_version.value(str_updateVersion)
        log.info("write alternate version text, ok")
        return True
    else:
        err_to_updateprogress("write alternate version text failed.\n")
        return False

def write_alternateversion_count():
    """ write alternate versioncount """
    if checkmount_alternate(True):
        fn = altversfilename(versioncounter_path)
        with open(fn, "w")as f:
           print(current_versioncounter +1, file=f)
        configui.btn_boot_current.value(0)
        configui.btn_boot_alternate.value(1)
        log.info("write alternate version count, ok")
        return True
    else:
        err_to_updateprogress("write alternate version count failed.\n")
        return False

