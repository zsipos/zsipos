// SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
//
// SPDX-License-Identifier: GPL-3.0-or-later

/*
 needed with fl_choice
#include "FL/fl_ask.H"
*/

Fl_Align get_align(Fl_Widget *w)
{
	return w->align();
}

Fl_Image *get_image(Fl_Widget *w)
{
	return w->image();
}

const char* get_label(Fl_Widget *w)
{
	return w->label();
}

Fl_Color get_labelcolor(Fl_Widget *w)
{
	return w->labelcolor();
}

Fl_Font get_labelfont(Fl_Widget *w)
{
	return w->labelfont();
}

Fl_Fontsize get_labelsize(Fl_Widget *w)
{
	return w->labelsize();
}

Fl_Labeltype get_labeltype(Fl_Widget *w)
{
	return w->labeltype();
}

int get_position(Fl_Input_* w)
{
	return w->position();
}

Fl_Widget *get_value(Fl_Tabs* w)
{
	return w->value();
}

float get_value(Fl_Progress* w)
{
	return w->value();
}

const char * get_value(Fl_Input_* w)
{
	return w->value();
}

char get_value(Fl_Button* w)
{
	return w->value();
}

int get_value(Fl_Check_Button* w)
{
	return w->value();
}

int get_value(Fl_Choice* w)
{
	return w->value();
}

double get_value(Fl_Valuator* w)
{
	return w->value();
}

float get_maximum(Fl_Progress* w)
{
	return w->maximum();
}

float get_minimum(Fl_Progress* w)
{
	return w->minimum();
}

Fl_Fontsize get_textsize(Fl_Text_Display* w)
{
    return w->textsize();
}

unsigned int is_visible(Fl_Widget* w)
{
	return w->visible_r();
}

