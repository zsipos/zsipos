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

cdef extern from "FL/Fl.H":

    ctypedef unsigned char bool
    ctypedef unsigned char uchar

    ctypedef unsigned Fl_Align

    cdef Fl_Align FL_ALIGN_CENTER
    cdef Fl_Align FL_ALIGN_TOP
    cdef Fl_Align FL_ALIGN_BOTTOM
    cdef Fl_Align FL_ALIGN_LEFT
    cdef Fl_Align FL_ALIGN_RIGHT
    cdef Fl_Align FL_ALIGN_INSIDE
    cdef Fl_Align FL_ALIGN_TEXT_OVER_IMAGE
    cdef Fl_Align FL_ALIGN_IMAGE_OVER_TEXT
    cdef Fl_Align FL_ALIGN_CLIP
    cdef Fl_Align FL_ALIGN_WRAP
    cdef Fl_Align FL_ALIGN_IMAGE_NEXT_TO_TEXT 
    cdef Fl_Align FL_ALIGN_TEXT_NEXT_TO_IMAGE
    cdef Fl_Align FL_ALIGN_IMAGE_BACKDROP
    cdef Fl_Align FL_ALIGN_TOP_LEFT
    cdef Fl_Align FL_ALIGN_TOP_RIGHT
    cdef Fl_Align FL_ALIGN_BOTTOM_LEFT
    cdef Fl_Align FL_ALIGN_BOTTOM_RIGHT
    cdef Fl_Align FL_ALIGN_LEFT_TOP
    cdef Fl_Align FL_ALIGN_RIGHT_TOP
    cdef Fl_Align FL_ALIGN_LEFT_BOTTOM
    cdef Fl_Align FL_ALIGN_RIGHT_BOTTOM
    cdef Fl_Align FL_ALIGN_NOWRAP
    cdef Fl_Align FL_ALIGN_POSITION_MASK
    cdef Fl_Align FL_ALIGN_IMAGE_MASK

    ctypedef unsigned int Fl_Color

    cdef Fl_Color FL_FOREGROUND_COLOR
    cdef Fl_Color FL_BACKGROUND2_COLOR
    cdef Fl_Color FL_INACTIVE_COLOR
    cdef Fl_Color FL_SELECTION_COLOR 
    cdef Fl_Color FL_GRAY0
    cdef Fl_Color FL_DARK3
    cdef Fl_Color FL_DARK2
    cdef Fl_Color FL_DARK1
    cdef Fl_Color FL_BACKGROUND_COLOR
    cdef Fl_Color FL_LIGHT1
    cdef Fl_Color FL_LIGHT2
    cdef Fl_Color FL_LIGHT3
    cdef Fl_Color FL_BLACK
    cdef Fl_Color FL_RED
    cdef Fl_Color FL_GREEN
    cdef Fl_Color FL_YELLOW
    cdef Fl_Color FL_BLUE
    cdef Fl_Color FL_MAGENTA
    cdef Fl_Color FL_CYAN
    cdef Fl_Color FL_DARK_RED
    cdef Fl_Color FL_DARK_GREEN
    cdef Fl_Color FL_DARK_YELLOW
    cdef Fl_Color FL_DARK_BLUE
    cdef Fl_Color FL_DARK_MAGENTA
    cdef Fl_Color FL_DARK_CYAN
    cdef Fl_Color FL_WHITE

    cdef Fl_Color fl_rgb_color(uchar r, uchar g, uchar b) nogil

    ctypedef int Fl_Font
    ctypedef int Fl_Fontsize

    cdef Fl_Font FL_HELVETICA
    cdef Fl_Font FL_HELVETICA_BOLD
    cdef Fl_Font FL_HELVETICA_ITALIC
    cdef Fl_Font FL_HELVETICA_BOLD_ITALIC
    cdef Fl_Font FL_COURIER
    cdef Fl_Font FL_COURIER_BOLD 
    cdef Fl_Font FL_COURIER_ITALIC
    cdef Fl_Font FL_COURIER_BOLD_ITALIC
    cdef Fl_Font FL_TIMES
    cdef Fl_Font FL_TIMES_BOLD
    cdef Fl_Font FL_TIMES_ITALIC
    cdef Fl_Font FL_TIMES_BOLD_ITALIC
    cdef Fl_Font FL_SYMBOL
    cdef Fl_Font FL_SCREEN
    cdef Fl_Font FL_SCREEN_BOLD
    cdef Fl_Font FL_ZAPF_DINGBATS

    cdef Fl_Font FL_FREE_FONT
    cdef Fl_Font FL_BOLD
    cdef Fl_Font FL_ITALIC
    cdef Fl_Font FL_BOLD_ITALIC

    ctypedef enum Fl_Labeltype:
        FL_NORMAL_LABEL,
        FL_NO_LABEL,
        _FL_SHADOW_LABEL,
        _FL_ENGRAVED_LABEL,
        _FL_EMBOSSED_LABEL,
        _FL_MULTI_LABEL,
        _FL_ICON_LABEL,
        _FL_IMAGE_LABEL,
        FL_FREE_LABELTYPE

    ctypedef void (*Fl_Awake_Handler)(void* arg)
    ctypedef void (*Fl_Callback)(Fl_Widget* widget, void* arg)

    cdef cppclass Fl:

        @staticmethod
        int         awake(Fl_Awake_Handler func, void* data) nogil
        @staticmethod
        unsigned    get_color(Fl_Color color) nogil
        @staticmethod
        const char* get_font(Fl_Font fnum) nogil
        @staticmethod
        const char* get_font_name(Fl_Font fnum, int* attributes) nogil
        @staticmethod
        int         check() nogil
        @staticmethod
        void        flush() nogil
        @staticmethod
        int         lock() nogil
        @staticmethod
        int         run() nogil
        @staticmethod
        void        set_font(Fl_Font fnum, Fl_Font _from) nogil
        @staticmethod
        Fl_Font     set_fonts(const char* xstarname) nogil


cdef extern from "FL/fl_draw.H":

    cdef void fl_font(Fl_Font face, Fl_Fontsize fsize) nogil


cdef extern from "FL/Fl_Widget.H":

    cdef cppclass Fl_Widget:

        void activate() nogil
        void align(Fl_Align alignment) nogil
        void callback(Fl_Callback callback, void* data) nogil
        void color(Fl_Color color) nogil
        void copy_label(const char* new_label) nogil
        void deactivate() nogil
        void hide() nogil
        void image(Fl_Image* image) nogil
        void label(const char* text) nogil
        void labelcolor(Fl_Color color) nogil
        void labelfont(Fl_Font font) nogil
        void labelsize(Fl_Fontsize size) nogil
        void labeltype(Fl_Labeltype type) nogil
        void position(int x, int y) nogil
        void redraw() nogil
        void redraw_label() nogil
        void resize(int x, int y, int w, int h) nogil
        void show() nogil
        int  take_focus()
        #void visible_focus(int v)

cdef extern from "FL/Fl_Box.H":

    cdef cppclass Fl_Box(Fl_Widget):
        pass


cdef extern from "FL/Fl_Group.H":

    cdef cppclass Fl_Group(Fl_Widget):

        void begin() nogil
        void end() nogil
        void init_sizes() nogil
        void remove(Fl_Widget *o) nogil


cdef extern from "FL/Fl_Window.H":

    cdef cppclass Fl_Window(Fl_Group):
        pass


cdef extern from "FL/Fl_Double_Window.H":

    cdef cppclass Fl_Double_Window(Fl_Window):

        void flush() nogil


cdef extern from "FL/Fl_Button.H":

    cdef cppclass Fl_Button(Fl_Widget):

        int value(int v)

cdef extern from "FL/Fl_Light_Button.H":

    cdef cppclass Fl_Light_Button(Fl_Button):
        pass

cdef extern from "FL/Fl_Check_Button.H":

    cdef cppclass Fl_Check_Button(Fl_Light_Button):
        pass

# RadioButton has problems, use RoundButton, type Radio

cdef extern from "FL/Fl_Round_Button.H":

    cdef cppclass Fl_Round_Button(Fl_Light_Button):
        pass

cdef extern from "FL/Fl_Browser_.H":

    cdef cppclass Fl_Browser_(Fl_Group):
        pass

cdef extern from "FL/Fl_Browser.H":

    cdef cppclass Fl_Browser(Fl_Browser_):
        void hide(int line) nogil
        void remove(int n) nogil
        int select(int line, int val)
        int selected(int line) nogil
        int size() nogil
        const char* text(int line) nogil
        int value() nogil # get value!


cdef extern from "FL/Fl_File_Browser.H":

    cdef cppclass Fl_File_Browser(Fl_Browser):

        void filetype(int t) nogil
        void filter(const char* pattern) nogil
        int load(const char* directory) nogil

cdef extern from "FL/Fl_Tabs.H":

    cdef cppclass Fl_Tabs(Fl_Group):

        int value(Fl_Widget* widget) nogil


cdef extern from "FL/Fl_Progress.H":

    cdef cppclass Fl_Progress(Fl_Widget):

        void maximum(float v) nogil
        void minimum(float v) nogil
        void value(float v) nogil


cdef extern from "FL/Fl_Image.H":

    cdef cppclass Fl_Image:
        pass


    cdef cppclass Fl_RGB_Image(Fl_Image):
        pass


cdef extern from "FL/Fl_GIF_Image.H":

    cdef cppclass Fl_GIF_Image(Fl_RGB_Image):

       Fl_GIF_Image(const char* filename) nogil


cdef extern from "FL/Fl_PNG_Image.H":

    cdef cppclass Fl_PNG_Image(Fl_RGB_Image):

        Fl_PNG_Image(const char* filename) nogil


cdef extern from "FL/Fl_PNM_Image.H":

    cdef cppclass Fl_PNM_Image(Fl_RGB_Image):

        Fl_PNM_Image(const char* filename) nogil


cdef extern from "FL/Fl_XPM_Image.H":

    cdef cppclass Fl_XPM_Image(Fl_RGB_Image):

        Fl_XPM_Image(const char* filename) nogil


cdef extern from "FL/Fl_Input_.H":

    cdef cppclass Fl_Input_(Fl_Widget):

        int cut(int n) nogil
        int insert(const char* t, int l) nogil
        int position(int p, int m) nogil
        int value(const char *) nogil

cdef extern from "FL/Fl_Input.H":

    cdef cppclass Fl_Input(Fl_Input_):
        pass

cdef extern from "FL/Fl_Int_Input.H":

    cdef cppclass Fl_Int_Input(Fl_Input):
        pass

cdef extern from "FL/Fl_Output.H":

    cdef cppclass Fl_Output(Fl_Input):
        pass

cdef extern from "FL/Fl_Multiline_Output.H":

    cdef cppclass Fl_Multiline_Output(Fl_Output):
        pass

cdef extern from "FL/Fl_Menu_.H":

    cdef cppclass Fl_Menu_(Fl_Widget):

        void add(const char *s) nogil

cdef extern from "FL/Fl_Choice.H":

    cdef cppclass Fl_Choice(Fl_Menu_):

        void value(int val) nogil


cdef extern from "FL/Fl_Valuator.H":

    cdef cppclass Fl_Valuator(Fl_Widget):

        int value(double) nogil

cdef extern from "FL/Fl_Counter.H":

    cdef cppclass Fl_Counter(Fl_Valuator):
        pass

cdef extern from "FL/Fl_Simple_Counter.H":

    cdef cppclass Fl_Simple_Counter(Fl_Counter):
        pass

cdef extern from "FL/Fl_Text_Display.H":
    cdef struct Style_Table_Entry:
        Fl_Color    Color
        Fl_Font     font
        Fl_Fontsize size
        unsigned    attr 

    ctypedef void (*Unfinished_Style_Cb)(int, void *)

    cdef cppclass Fl_Text_Display(Fl_Group):
        void buffer(Fl_Text_Buffer *buf) nogil
        int count_lines(int startPos, int endPos, bool startPosisLineStart)
        void highlight_data(Fl_Text_Buffer *styleBuffer, 
                            const Style_Table_Entry *styleTable, 
                            int nStyles,
                            char unfinishedStyle,
                            Unfinished_Style_Cb unfinishedHighlightCb,
                            void *cbArg) nogil
        void scroll(int topLineNum, int horizOffset) nogil
        void scrollbar_width(int w) nogil
        void textsize(Fl_Fontsize s) nogil
        void wrap_mode(int wrap, int wrapMargin) nogil

cdef extern from "FL/Fl_Text_Buffer.H":

    cdef cppclass Fl_Text_Buffer:
        int length() nogil
        void text(const char* text) nogil


#
# some helper functions
#
cdef extern from "../fltk.cpp":
    cdef Fl_Align     get_align(Fl_Widget* widget) nogil
    cdef Fl_Image     get_image(Fl_Widget* widget) nogil
    cdef const char*  get_label(Fl_Widget* widget) nogil
    cdef Fl_Color     get_labelcolor(Fl_Widget* widget) nogil
    cdef Fl_Font      get_labelfont(Fl_Widget* widget) nogil
    cdef Fl_Fontsize  get_labelsize(Fl_Widget* widget) nogil
    cdef Fl_Labeltype get_labeltype(Fl_Widget* widget) nogil
    cdef int          get_position(Fl_Input_* input_) nogil
    cdef Fl_Widget*   get_value(Fl_Tabs* widget) nogil
    cdef float        get_value(Fl_Progress* widget) nogil
    cdef char         get_value(Fl_Button* widget) nogil
    cdef const char*  get_value(Fl_Input_* input_) nogil
    cdef int          get_value(Fl_Choice* widget) nogil
    cdef double       get_value(Fl_Valuator* valuator) nogil
    cdef float        get_maximum(Fl_Progress* widget) nogil
    cdef float        get_minimum(Fl_Progress* widget) nogil
    cdef Fl_Fontsize  get_textsize(Fl_Text_Display* widget) nogil
    cdef unsigned int is_visible(Fl_Widget* widget) nogil
