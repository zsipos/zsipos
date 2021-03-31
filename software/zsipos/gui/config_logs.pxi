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
#config_logs.pxi
#
# Author: Esther Bergter
#
# Version 1.0

import io

# keep consistent with consts.py Logging
logconsts = [ consts.LOGEXT, consts.LOGLOC, consts.LOGFULLMESSAGE,
  consts.LOGCCEVENTS, consts.LOGCCMESSAGES, consts.LOGBMEVENTS,
  consts.LOGSIPTIMING, consts.LOGTIMERS, consts.SIPDELAY, consts.LOGZRTPCB,
  consts.LOGZSESSIONCB, consts.LOGICE, consts.LOGDTMF, consts.PJLOGLEVEL ]

logs_initialized = False
sendfiles = set()

#Group Logs
def group_logs_init():
    global logs_initialized

    ui = configui
    ui.btn_help.hide()

    if logs_initialized:
        clearsendfiles()
        return

    ui.btn_logsettings.callback(on_btn_logsettings, NULL)

    ui.btn_uploaduri.callback(on_btn_uploaduri, NULL)
    ui.btn_uploaduri.value(" Upload Server")
    ui.btn_uploaduri.copy_label(disp_upload(consts.UPLOADURI, consts.UPLOADID))
    ui.btn_ping_uploaduri.callback(on_btn_ping_uploaduri, NULL)

    ui.btn_nohup.callback(on_btn_nohup, NULL)
    ui.btn_zsiposlog.callback(on_btn_zsiposlog, NULL)

    ui.browse_archive.load(current_archive)
    ui.browse_archive.remove(1) # hide ../
    ui.browse_archive.callback(on_browser_archive_click, NULL)
    ui.btn_upload.callback(on_btn_upload, NULL)
    ui.btn_alternate_archive.callback(on_btn_alternate_archive, NULL)
    # subwindow WinLogSettings
    ui.btn_logsettings_back.callback(on_btn_logsettings_back, NULL)
    ui.log_external.value(cfdict[consts.LOGEXT])
    ui.log_external.callback(on_btn_log, <void*>consts.LOGEXT)
    ui.log_local.value(cfdict[consts.LOGLOC])
    ui.log_local.callback(on_btn_log, <void*>consts.LOGLOC)
    ui.log_full.value(cfdict[consts.LOGFULLMESSAGE])
    ui.log_full.callback(on_btn_log, <void*>consts.LOGFULLMESSAGE)
    ui.log_cc_events.value(cfdict[consts.LOGCCEVENTS])
    ui.log_cc_events.callback(on_btn_log, <void*>consts.LOGCCEVENTS)
    ui.log_cc_messages.value(cfdict[consts.LOGCCMESSAGES])
    ui.log_cc_messages.callback(on_btn_log, <void*>consts.LOGCCMESSAGES)
    ui.log_bm_events.value(cfdict[consts.LOGBMEVENTS])
    ui.log_bm_events.callback(on_btn_log, <void*>consts.LOGBMEVENTS)
    ui.log_timers.value(cfdict[consts.LOGTIMERS])
    ui.log_timers.callback(on_btn_log, <void*>consts.LOGTIMERS)
    ui.log_sip_proctime.value(cfdict[consts.LOGSIPTIMING])
    ui.log_sip_proctime.callback(on_btn_log, <void*>consts.LOGSIPTIMING)
    ui.log_sip_debug_delay.value(cfdict[consts.SIPDELAY])
    ui.log_sip_debug_delay.callback(on_btn_log, <void*>consts.SIPDELAY)
    ui.log_zrtp_events.value(cfdict[consts.LOGZRTPCB])
    ui.log_zrtp_events.callback(on_btn_log, <void*>consts.LOGZRTPCB)
    ui.log_zsession_events.value(cfdict[consts.LOGZSESSIONCB])
    ui.log_zsession_events.callback(on_btn_log, <void*>consts.LOGZSESSIONCB)
    ui.log_ice.value(cfdict[consts.LOGICE])
    ui.log_ice.callback(on_btn_log, <void*>consts.LOGICE)
    ui.log_dtmf.value(cfdict[consts.LOGDTMF])
    ui.log_dtmf.callback(on_btn_log, <void*>consts.LOGDTMF)
    ui.log_level.value(float(cfdict[consts.PJLOGLEVEL]))
    ui.log_level.callback(on_btn_log_level, <void*>consts.PJLOGLEVEL)
    # no files to send yet
    clearsendfiles()
    logs_initialized = True


#callbacks
cdef void on_btn_addfile(Fl_Widget* widget, void *cfdata) with gil:
    """ add/remove nohup.out, zsipos.log """
    myitem = <Fl_Button*>cfdata
    myfile = get_label(myitem)
    if get_value(myitem):
        log.info("on_btn_addfile: add %s" %(myfile,))
        add_file(myfile)
    else:
        log.info("on_btn_addfile: remove %s" %(myfile,))
        remove_file(myfile)

cdef void on_btn_alternate_archive(Fl_Widget* widget, void *data) with gil:
    """ switch between local and alternate archive """
    global current_archive

    if get_value(configui.btn_alternate_archive) == 0:   # lokales archiv
        current_archive=local_archive_path
        configui.browse_archive.copy_label(empty_label) # erase longer value
    else:                                                # alternatives archiv
        if checkmount_alternate(True): # mount alternate erfolgreich
            if not os.path.exists(alternate_archive_path):
                os.makedirs(alternate_archive_path)
            current_archive=alternate_archive_path
            configui.browse_archive.copy_label(alternate_archive_path)
        else:
            current_archive=local_archive_path
            configui.browse_archive.copy_label(empty_label) # erase longer value
    configui.browse_archive.load(current_archive)
    configui.browse_archive.remove(1) # hide ../
    # now mark all selected files
    size = configui.browse_archive.size()
    for index in range(1, size+1):
        filename = configui.browse_archive.text(index)
        relfile = os.path.join(current_archive, filename)
        if relfile in sendfiles:
            configui.browse_archive.select(index,1)

cdef void on_browser_archive_click(Fl_Widget* widget, void *data) with gil:
    """ add/remove files from archive """
    global sendfiles

    #log.info("on_browser_archive_click: sendfiles %s" %(sendfiles))
    size = configui.browse_archive.size()
    for index in range(1, size+1):
        filename = configui.browse_archive.text(index)
        relfile = os.path.join(current_archive, filename)
        if configui.browse_archive.selected(index):
            if relfile in sendfiles:
                log.info("on_browser_archive_click: remove %s" %(filename,))
                remove_file(relfile)
                configui.browse_archive.select(index,0) # deselect
            else:
                log.info("on_browser_archive_click: add %s" %(filename,))
                add_file(relfile)
        else:
            if relfile in sendfiles:
                configui.browse_archive.select(index,1) # select

cdef void on_btn_logsettings(Fl_Widget* widget, void *data) with gil:
    configui.winLogSettings.show()

cdef void on_btn_nohup(Fl_Widget* widget, void *data) with gil:
    debug('on_btn_nohup')
    if get_value(configui.btn_nohup):
        add_file_snapshot('nohup.out')
    else:
        remove_file_snapshot('nohup.out')

cdef void on_btn_zsiposlog(Fl_Widget* widget, void *data) with gil:
    debug('on_btn_zsiposlog')
    if get_value(configui.btn_zsiposlog):
        ret = add_file_snapshot('zsipos.log')
    else:
        remove_file_snapshot('zsipos.log')

cdef void on_btn_ping_uploaduri(Fl_Widget* widget, void *data) with gil:
    ping_url_path(consts.UPLOADURI)

cdef void on_btn_upload(Fl_Widget* widget, void *data) with gil:
    if len(sendfiles) > 0:
        if not config_valid(consts.UPLOADID):
            if not config_valid(consts.UPLOADURI):
                warn('Upload information missing')
                return;
            else:
                on_btn_uploadid(NULL, <void*>consts.UPLOADID)
                info('Please press send button again.')
                return;
        sendfiles.add('Manifest.txt')
        make_Manifest()
        do_send()
    else:
        warn('no files selected')

cdef void on_btn_uploadid(Fl_Widget *widget, void *data) with gil:
    global my_edit
    class Edit_Simple(EditAddress):
        def __init__(self, var, ty):
            self.var = var
            super().__init__(
            title='Upload Id',
            options=[var],
            type=ty)

        def OkPressed(self):
            debug("OkPressed")

        def Cancel(self):
            debug("Cancel")

    my_edit = Edit_Simple(consts.UPLOADID, 'uploadid')

cdef void on_btn_uploaduri(Fl_Widget *widget, void *data) with gil:
    global my_edit
    btn = configui.btn_uploaduri
    class Edit_Split(EditAddress_split):
        def __init__(self, var, ty, **kwargs):
            debug(f'Edit_Split: {kwargs}')
            nonlocal btn
            self.url = var
            self.id = kwargs['uploadid']
            super().__init__(
            title = get_value(btn).strip(),
            options = [self.url, self.id],
            forcehttp = kwargs['forcehttp'] if 'forcehttp' in kwargs else None,
            type = ty)

        def OkPressed(self):
            nonlocal btn
            debug("OkPressed")
            newval = disp_upload(self.url, self.id)
            btn.copy_label(newval)

        def Cancel(self):
            debug("Cancel")
    if is_testversion():
        my_edit = Edit_Split(consts.UPLOADURI, 'upload', uploadid=consts.UPLOADID)
    else:
        my_edit = Edit_Split(consts.UPLOADURI, 'upload', uploadid=consts.UPLOADID, forcehttp='https')

# winLogSettings
cdef void on_btn_logsettings_back(Fl_Widget* widget, void *data) with gil:
    configui.winLogSettings.hide()

cdef void on_btn_log(Fl_Widget* widget, void *data) with gil:
    myname = <str>data
    mywidget = <Fl_Check_Button*>widget
    cfdict[myname] = to_bool(get_value(mywidget))
    debug(f'on_btn_log: {myname} = {cfdict[myname]}')

cdef void on_btn_log_level(Fl_Widget* widget, void *data) with gil:
    myname = <str>data
    mywidget = <Fl_Check_Button*>widget
    cfdict[myname] = str(int(get_value(mywidget)))
    debug(f'on_btn_log: {myname} = {cfdict[myname]}')


# python
def add_file(filename):
    global sendfiles;

    if os.path.isfile(filename):
        if filename not in sendfiles:
            sendfiles.add(filename)
    log.info("add_file: sendfiles %s" %(sendfiles))

def add_file_snapshot(filename):
    newname = '_' + filename
    try:
        shutil.copy2(filename, newname)
    except:
        logerrorexception('help')
        return False
    else:
        sendfiles.add(newname)
        log.info("add_file_snapshot: sendfiles %s" %(sendfiles))
        return True

def add_stdfiles():
    global sendfiles
    ret = True
    sendfiles.add('Manifest.txt')
    return ret

def clearsendfiles():
    global sendfiles

    sendfiles = set()
    size = configui.browse_archive.size()
    for index in range(1, size+1):
        configui.browse_archive.select(index,0)
    configui.btn_nohup.value(0)
    configui.btn_zsiposlog.value(0)

def config_valid(name):
    """ True if cfdict[name] is defined """
    return True if name in cfdict and cfdict[name] else False

def do_send_http(url, files):

    class MyIter:
        """local iterator class with len function for progess display"""

        def __init__(self):
            self.done = 0

        def __iter__(self):
            return self

        def __next__(self):
            block = proc_tar.stdout.read(chunk_size)
            if block == b"":
                proc_tar.wait()
                raise StopIteration
            self.done += len(block)
            refresh_percent(100 * self.done // total_size)
            return block

        def __len__(self):
            return total_size

    def to_upload_progress(s):
        append_help(s)
        Fl.check()

    def refresh_percent(percent):
        nonlocal mypos, lastpos, last_percent

        if (percent > last_percent):
            if (percent > 100):
                percent = 100
            last_percent = percent
            what = f'{percent}%'
            replace_help(mypos, lastpos, what)
            lastpos = mypos + len(what)
        Fl.check()

    def safe_del(name):
        if os.path.exists(name):
            os.remove(name)

    data = MyIter()
    configui.btn_help_back.hide()
    what = "uploading logfiles started...\n"
    show_help("upload", what)
    chunk_size = 1024 * 8
    last_percent = -1
    total_size = 0
    try:
        for i in files:
            total_size += 512 #file header
            file_size = os.path.getsize(i)
            blocks = file_size // 512
            if file_size % 512: #pad last block
                blocks += 1
            total_size += blocks * 512
        total_size += 1024 #end blocks
        proc_tar = subprocess.Popen(["tar",  "cf",  "-"] + list(files), stdout=subprocess.PIPE)
        to_upload_progress("uploading: ")
        mypos = get_help_length()
        lastpos = mypos +1
        headers = {'content-type': 'application/octet-stream'}
        reply=requests.post(url, data=data, headers=headers)
        log.debug(reply.text)
        refresh_percent(100)
        clearsendfiles()
        to_upload_progress("done.\nall selected logfiles uploaded.\n")

    except:
        logerrorexception('help')
        raise

    finally:
        configui.btn_help_back.show()
        safe_del("_zsipos.log")
        safe_del("_nohup.out")
        safe_del("Manifest.txt")

def do_send():
    log.info(f'send {sendfiles}')
    do_send_http(cfdict[consts.UPLOADURI], sendfiles)
    return
#do_send

def log_changed():
    """ return True if a key in logconsts changed """
    for key in logconsts:
        if key in cfdict:
            if key in olddict:
                if olddict[key] != cfdict[key]:
                    log.info(key + " changed")
                    return True
            else:
                log.info(key * " added")
                return True
        else:
            if key in olddict:
                log.info(key + " deleted")
                return True

def make_Manifest():
    mversion = '0.1'
    file = open('Manifest.txt', 'w')
    file.write('Manifest Version %s\n' % (mversion))
    file.write('    Customer:  %s\n' % (cfdict[consts.UPLOADID], ))
    file.write('    Timestamp: %s\n' % (tstr(int(time()))))
    file.write('\nVersions:\n')
    file.write("    GIT-MAGIC: %s\n" % (hex(getGitMagic())))
    for i in sorted(gitversions):
        file.write("    %s\n" % (gitFormat(i), ))
    file.write('\nFiles:\n')
    for fn in sorted(sendfiles):
        file.write('    %s\n' % (fn,))
    file.write('\nConfig:\n')
    for key, value in sorted(cfdict.items()):
        if key == 'AutoDns':
            continue
        if key == 'turnPassword':
            file.write("    %s=****" % (key,))
        else:
            file.write("    %s=%s" % (key, str(value)))
        file.write('\n')
#make_Manifest

def remove_file(char *filename):
    global sendfiles;

    if filename in sendfiles:
        sendfiles.remove(filename)

def remove_file_snapshot(char *filename):
    global sendfiles;
    newname = '_' + filename

    if newname in sendfiles:
        sendfiles.remove(newname)
        os.unlink(newname)
        log.info(f'remove_file_snapshot: sendfiles {newname} removed')

