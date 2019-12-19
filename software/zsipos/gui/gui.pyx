"""
Copyright (C) 2017 Stefan Adams

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

# cython: c_string_type=unicode, c_string_encoding=utf8

from libcpp cimport bool
import logging
from threading import Event, Thread
import weakref 

from config import config
import rtp
import consts
from fltk cimport *
from GMITM import GMITMEventListener
from utils import parseAddress, PYCALL
from console import console

log = logging.getLogger("gui")

cdef bool dolog = True

##########
# MAINUI #
##########

cdef MAINUI* mainui
cdef extern from *:

    cdef void exit(int code) nogil
    
    
cdef void on_close(Fl_Widget *widget, void *data) with gil:
    mainui.window.hide()
    exit(0)


cdef void on_btn_config(Fl_Widget *widget, void *data) with gil:
    on_config_enter(widget, data) 


cdef void app_main() nogil:
    global mainui
    mainui = new MAINUI()
    mainui.window.callback(on_close, NULL)
    mainui.btn_config.callback(on_btn_config, NULL)
    mainui.btn_mute.image(icon_rtp_on)
    mainui.btn_info.image(icon_info)
    mainui.btn_config.image(icon_gear)
    with gil:
        configui_init("")
    mainui.window.show()
    with gil:
        loadfonts()
        log.debug("background color: %s", hex(Fl.get_color(FL_BACKGROUND_COLOR)))
    Fl.lock()
    with gil:
        ready_event.set()
        log.info("gui is ready")
    Fl.run()
    
def cfg_main(infstr):
    configui_init(infstr)
    loadfonts()
    on_config_enter(NULL, NULL)
    Fl.lock()
    Fl.run()

##########
# CALLUI #
##########

cdef void on_btn_encrypt(Fl_Widget* widget, void* data) with gil:
    call = <Call>data
    call.cc.goSecure()

cdef void on_btn_verify(Fl_Widget* widget, void *data) with gil:
    call = <Call>data
    if call.verified:
        call.verified = False
        call.cc.resetSASVerified()
    else:
        call.verified = True
        call.cc.setSASVerified()
    call.drawSAS()

cdef class Call(object):

    cdef CALLUI* callui
    cdef object  cc
    cdef int     laststate
    cdef object  cipher 
    cdef object  sas
    cdef int     verified
    # for string references
    cdef object  addrstr
    cdef object  statusstr

    def __init__(self, cc, msg):
        cdef CALLUI *ui
        self.laststate = rtp.CRYPTO_STATEINFO_NONE - 1
        if dolog: log.debug("call object created")
        self.cc = weakref.ref(cc)()
        mainui.tab_call.begin()
        ui = self.callui = new CALLUI(<void*>self)
        ui.window.position(0, 60)
        ui.window.labeltype(FL_NORMAL_LABEL)
        ui.progress.minimum(rtp.CRYPTO_STATEINFO_NONE)
        ui.progress.maximum(rtp.CRYPTO_STATEINFO_CONNECTED)
        self.setStatusStr("Waiting for connection ...")
        if cc.get_is_incoming():
            # incoming call
            adr = parseAddress(msg.headers['from'][0])
            ui.window.label('incoming')
            ui.window.image(icon_call_i_connect)
            ui.btn_direction.image(icon_info_call_i)
        else:
            # outgoing call
            adr = parseAddress(msg.headers['to'][0])
            ui.window.label('outgoing')
            ui.window.image(icon_call_o_connect)
            ui.btn_direction.image(icon_info_call_o)
        addrstr = adr[1].username
        if len(adr[0]) and adr[0] != adr[1].username:
            addrstr += ' (' + adr[0] + ')'
        self.setAddrStr(addrstr)
        mainui.tab_call.end()
        mainui.tab_call.value(self.callui.window)
        ui.btn_encrypt.callback(on_btn_encrypt, <void*>self)
        ui.btn_verify.callback(on_btn_verify, <void*>self)
        mainui.window.redraw()

    def __dealloc__(self):
        if dolog: log.debug("call object deleted")
        if self.callui:
            mainui.tab_call.remove(self.callui.window)
            del self.callui
            self.callui = NULL
            mainui.window.redraw()

    def setAddrStr(self, s):
        self.addrstr = s
        self.callui.btn_callinfo.label(self.addrstr)

    def setStatusStr(self, s):
        self.statusstr = s
        self.callui.btn_status.label(s)

    def doUpdateState(self, s):
        cdef CALLUI *ui = self.callui
        ui.progress.value(s)
        if s == rtp.CRYPTO_STATEINFO_NONE:
            ui.btn_ringing.hide()
            ui.btn_encrypt.show()
            ui.btn_secstate.image(icon_secure_off)
            self.setStatusStr("The call is not encrypted.")
        elif s == rtp.CRYPTO_STATEINFO_ZRTP1:
            ui.btn_encrypt.hide()
            ui.grp_sas.show()
            ui.progress.show()
            ui.progress.label("1. zrtp attempt")
            self.setStatusStr("Encrypting call ...")
            ui.btn_status.labelcolor(FL_BLACK)
        elif s == rtp.CRYPTO_STATEINFO_LOCAL_OFFER:
            ui.progress.label("local offer")
        elif s == rtp.CRYPTO_STATEINFO_DTMF_EXCHANGE:
            ui.progress.label("dtmf exchange")
        elif s == rtp.CRYPTO_STATEINFO_ICE:
            ui.progress.label("interactive connectivity exchange")
        elif s == rtp.CRYPTO_STATEINFO_ZRTP2:
            ui.progress.label("2. zrtp attempt")
        elif s == rtp.CRYPTO_STATEINFO_CONNECTED:
            ui.progress.hide()
        elif s == rtp.CRYPTO_STATEINFO_FAILED:
            self.drawERROR()
        else:
            log.error("state CRYPTO_STATEINFO_%d not handled", s)
        mainui.window.redraw()

    def updateState(self, s):
        for i in xrange(self.laststate + 1, s + 1):
            self.doUpdateState(i)
        self.laststate = s 

    def drawSAS(self):
        cdef CALLUI *ui = self.callui
        if self.verified:
            self.setStatusStr("The call is encrypted. (" + self.cipher + ")")
            ui.btn_sas.labelcolor(color_locked)
            ui.btn_verify.image(icon_cancel)
            ui.btn_verify.label("unverify")
            ui.btn_secstate.image(icon_secure_on)
        else:
            self.setStatusStr("The call is encrypted, but the SAS is not verified.")
            ui.btn_sas.labelcolor(color_warning)
            ui.btn_verify.image(icon_checked)
            ui.btn_verify.label("verify")
            ui.btn_secstate.image(icon_secure_warning)
        ui.btn_sas.label(self.sas) 
        ui.btn_verify.activate()
        mainui.window.redraw()

    def drawERROR(self):
        cdef CALLUI *ui = self.callui
        status = self.cc.getStatus()
        if status.ice_state == rtp.ICE_STATE_FAILED:
            self.setStatusStr("ICE connection failed.")
        else:
            severity_str = rtp.zrtp_MessageSeverity_names[status.failed[0]]
            subcode_str  = rtp.zrtp_SeveritySubCode_names[status.failed[0]][abs(status.failed[1])]
            self.setStatusStr("ZRTP connection failed, " + severity_str + ": " + subcode_str)
        ui.grp_sas.hide()
        ui.btn_secstate.image(icon_secure_off)
        ui.btn_stop.show()
        mainui.window.redraw()

    def onSecureOn(self, cipher, sas, verified):
        self.cipher = cipher 
        self.sas = sas
        self.verified = verified
        self.drawSAS()

#
# External events
#
class GUI_GMITMEventListener(GMITMEventListener):
    
    def onCallCreated(self, cc, msg):
        def ___():
            if dolog: log.info("onCallCreated")
            call = Call(cc, msg)
            setattr(cc, "ui", call)
        callGUI(___)

    def onCallTerminated(self, cc, msg, code):       
        def ___():
            if dolog: log.info("onCallTerminated")
            delattr(cc, "ui")
        callGUI(___)
        
    def onCryptoStateInfo(self, cc, state):
        def ___():
            if dolog: log.info("onCryptoStateInfo")
            cc.ui.updateState(state)
        callGUI(___)
        
    def onSecureOn(self, cc, cipher, sas, verified):
        def ___():
            if dolog: log.info("onSecureOn")
            cc.ui.onSecureOn(cipher, sas, verified)
        callGUI(___)
        
    def onZrtpFailed(self, cc):
        def ___():
            if dolog: log.info("onZrtpFailed")
            cc.ui.drawERROR()
        callGUI(___)
                
    def onICEFailed(self, cc):
        def ___():
            if dolog: log.info("onICEFailed")
            cc.ui.drawERROR()
        callGUI(___)


#########
# FONTS #
#########

def loadfonts():
    count = Fl.set_fonts("-*")
    #for i in xrange(count):
    #    print(i, ":", Fl.get_font_name(i, NULL))
    #Fl.set_font(FL_TIMES, 17)

##########
# COLORS #
##########

cdef Fl_Color color_locked   = fl_rgb_color(0x00, 0x7A, 0x00)
cdef Fl_Color color_warning  = fl_rgb_color(0xFF, 0xCD, 0x00)

#########
# ICONS #
#########

icondir = config.get(consts.SECTION, consts.ICONDIR) + "/"

cdef Fl_Image* loadicon(name) with gil:
    name = icondir + name + '.png'
    cdef Fl_Image* ret = new Fl_PNG_Image(name)
    assert ret, "can not load icon '" + name + "'"
    return ret


cdef Fl_Image* icon_call_i_connect = loadicon("call_i_connect")
cdef Fl_Image* icon_call_o_connect = loadicon("call_o_connect")

cdef Fl_Image* icon_rtp_mute = loadicon("rtp_mute")
cdef Fl_Image* icon_rtp_on   = loadicon("rtp_on")

cdef Fl_Image* icon_info = loadicon("info")

cdef Fl_Image* icon_gear = loadicon("gear")

cdef Fl_Image* icon_info_call_i = loadicon("info_call_i")
cdef Fl_Image* icon_info_call_o = loadicon("info_call_o")

cdef Fl_Image* icon_secure_on       = loadicon("padlock")
cdef Fl_Image* icon_secure_off      = loadicon("unlocked")
cdef Fl_Image* icon_secure_inactive = loadicon("unlocked_inactive")
cdef Fl_Image* icon_secure_warning  = loadicon("warning-sign")
cdef Fl_Image* icon_secure_stop     = loadicon("stop")

cdef Fl_Image* icon_checked = loadicon("checked")
cdef Fl_Image* icon_cancel  = loadicon("cancel")

#
# Helper/Glue code
#
cdef extern from *: # @DuplicateSignature

    cdef void __Pyx_INCREF(void*) nogil    
    cdef void __Pyx_DECREF(void*) nogil

cdef void awake_callback(void *data) with gil:
    (<object>data).call()
    __Pyx_DECREF(data)

def callGUI(func, *args, **kwargs):
    cargs = PYCALL(func, args, kwargs)
    __Pyx_INCREF(<void*>cargs)
    Fl.awake(awake_callback, <void*>cargs)
    

class GUIThread(Thread):
    
    def __init__(self, thread_init_cb):
        self.thread_init_cb = thread_init_cb
        Thread.__init__(self)

    def run(self):
        self.thread_init_cb()
        with nogil: app_main()

cdef object thread
cdef object ready_event

def init(thread_init_cb):
    global ready_event, thread
    ready_event = Event()
    thread = GUIThread(thread_init_cb)
    thread.start()
    ready_event.wait()

def close():
    def __():
        global mainui
        if mainui:
            del mainui.window
            del mainui
            mainui = NULL
    callGUI(__)
    thread.join()

#
# GUI classes
#
cdef extern from "gui.cxx":

    cdef cppclass MAINUI:

        Fl_Double_Window* window        
        Fl_Tabs*          tab_call
        Fl_Button*        btn_mute
        Fl_Button*        btn_info        
        Fl_Button*        btn_config
        Fl_Button*        btn_onhook

        MAINUI() nogil


    cdef cppclass CALLUI:

        Fl_Group*    window
        Fl_Button*   btn_callinfo
        Fl_Button*   btn_status
        Fl_Button*   btn_direction
        Fl_Button*   btn_encrypt
        Fl_Button*   btn_secstate
        Fl_Button*   btn_ringing
        Fl_Progress* progress
        Fl_Group*    grp_sas
        Fl_Button*   btn_sas
        Fl_Button*   btn_verify
        Fl_Button*   btn_stop

        CALLUI(void* pyobj) nogil

include 'configui.pxi'
