/* keys.h - the FM Towns keyboard as the wire carries it.
 *
 * One line a key, in the order the keys follow the pads and the mouse on
 * the wire (waterbox.config "input.buttons"): the control's name after
 * "Key ", Geartowns' key code, the one character a movie writes for it,
 * the header TAStudio shows over its column, and the host key Chimera
 * binds to it by default ("" for none). tools/gen-config.py reads this
 * file to write the input part of waterbox.config and default_keybinds.json,
 * and waterbox/tests/check-config.py checks the three agree.
 */
#ifndef CHIMERA_GEARTOWNS_KEYS_H
#define CHIMERA_GEARTOWNS_KEYS_H

#define KEY_LIST \
	KEY("Escape", GT_KEY_ESCAPE, "e", "ESC", "Escape") \
	KEY("1", GT_KEY_1, "1", "1", "Number1") \
	KEY("2", GT_KEY_2, "2", "2", "Number2") \
	KEY("3", GT_KEY_3, "3", "3", "Number3") \
	KEY("4", GT_KEY_4, "4", "4", "Number4") \
	KEY("5", GT_KEY_5, "5", "5", "Number5") \
	KEY("6", GT_KEY_6, "6", "6", "Number6") \
	KEY("7", GT_KEY_7, "7", "7", "Number7") \
	KEY("8", GT_KEY_8, "8", "8", "Number8") \
	KEY("9", GT_KEY_9, "9", "9", "Number9") \
	KEY("0", GT_KEY_0, "0", "0", "Number0") \
	KEY("Minus", GT_KEY_MINUS, "-", "-", "Minus") \
	KEY("Caret", GT_KEY_CARET, "^", "^", "Equals") \
	KEY("Yen", GT_KEY_YEN, "y", "YEN", "Backslash") \
	KEY("Backspace", GT_KEY_BACKSPACE, "b", "BS", "Backspace") \
	KEY("Tab", GT_KEY_TAB, "t", "TAB", "Tab") \
	KEY("Q", GT_KEY_Q, "Q", "Q", "Q") \
	KEY("W", GT_KEY_W, "W", "W", "W") \
	KEY("E", GT_KEY_E, "E", "E", "E") \
	KEY("R", GT_KEY_R, "R", "R", "R") \
	KEY("T", GT_KEY_T, "T", "T", "T") \
	KEY("Y", GT_KEY_Y, "Y", "Y", "Y") \
	KEY("U", GT_KEY_U, "U", "U", "U") \
	KEY("I", GT_KEY_I, "I", "I", "I") \
	KEY("O", GT_KEY_O, "O", "O", "O") \
	KEY("P", GT_KEY_P, "P", "P", "P") \
	KEY("At", GT_KEY_AT, "@", "@", "Backtick") \
	KEY("Left Bracket", GT_KEY_LEFT_BRACKET, "[", "[", "LeftBracket") \
	KEY("Return", GT_KEY_RETURN, "r", "RET", "Enter") \
	KEY("A", GT_KEY_A, "A", "A", "A") \
	KEY("S", GT_KEY_S, "S", "S", "S") \
	KEY("D", GT_KEY_D, "D", "D", "D") \
	KEY("F", GT_KEY_F, "F", "F", "F") \
	KEY("G", GT_KEY_G, "G", "G", "G") \
	KEY("H", GT_KEY_H, "H", "H", "H") \
	KEY("J", GT_KEY_J, "J", "J", "J") \
	KEY("K", GT_KEY_K, "K", "K", "K") \
	KEY("L", GT_KEY_L, "L", "L", "L") \
	KEY("Semicolon", GT_KEY_SEMICOLON, ";", ";", "Semicolon") \
	KEY("Colon", GT_KEY_COLON, ":", ":", "Apostrophe") \
	KEY("Right Bracket", GT_KEY_RIGHT_BRACKET, "]", "]", "RightBracket") \
	KEY("Z", GT_KEY_Z, "Z", "Z", "Z") \
	KEY("X", GT_KEY_X, "X", "X", "X") \
	KEY("C", GT_KEY_C, "C", "C", "C") \
	KEY("V", GT_KEY_V, "V", "V", "V") \
	KEY("B", GT_KEY_B, "B", "B", "B") \
	KEY("N", GT_KEY_N, "N", "N", "N") \
	KEY("M", GT_KEY_M, "M", "M", "M") \
	KEY("Comma", GT_KEY_COMMA, ",", ",", "Comma") \
	KEY("Period", GT_KEY_PERIOD, "o", ".", "Period") \
	KEY("Slash", GT_KEY_SLASH, "/", "/", "Slash") \
	KEY("Underscore", GT_KEY_UNDERSCORE, "_", "_", "OEM102") \
	KEY("Space", GT_KEY_SPACE, "s", "SPC", "Space") \
	KEY("Keypad Multiply", GT_KEY_KP_MULTIPLY, "*", "K*", "KeypadMultiply") \
	KEY("Keypad Divide", GT_KEY_KP_DIVIDE, "%", "K/", "KeypadDivide") \
	KEY("Keypad Plus", GT_KEY_KP_PLUS, "+", "K+", "KeypadAdd") \
	KEY("Keypad Minus", GT_KEY_KP_MINUS, "~", "K-", "KeypadSubtract") \
	KEY("Keypad 7", GT_KEY_KP_7, "&", "K7", "Keypad7") \
	KEY("Keypad 8", GT_KEY_KP_8, "(", "K8", "Keypad8") \
	KEY("Keypad 9", GT_KEY_KP_9, ")", "K9", "Keypad9") \
	KEY("Keypad Equals", GT_KEY_KP_EQUALS, "=", "K=", "") \
	KEY("Keypad 4", GT_KEY_KP_4, "$", "K4", "Keypad4") \
	KEY("Keypad 5", GT_KEY_KP_5, "#", "K5", "Keypad5") \
	KEY("Keypad 6", GT_KEY_KP_6, "!", "K6", "Keypad6") \
	KEY("Keypad 1", GT_KEY_KP_1, "<", "K1", "Keypad1") \
	KEY("Keypad 2", GT_KEY_KP_2, "\"", "K2", "Keypad2") \
	KEY("Keypad 3", GT_KEY_KP_3, ">", "K3", "Keypad3") \
	KEY("Keypad Enter", GT_KEY_KP_ENTER, "'", "KENT", "KeypadEnter") \
	KEY("Keypad 0", GT_KEY_KP_0, "`", "K0", "Keypad0") \
	KEY("Keypad Period", GT_KEY_KP_PERIOD, "?", "K.", "KeypadDecimal") \
	KEY("Insert", GT_KEY_INSERT, "i", "INS", "Insert") \
	KEY("Keypad 000", GT_KEY_KP_000, "{", "K000", "") \
	KEY("Delete", GT_KEY_DELETE, "d", "DEL", "Delete") \
	KEY("Up", GT_KEY_UP, "u", "UP", "Up") \
	KEY("Home", GT_KEY_HOME, "h", "HOME", "Home") \
	KEY("Left", GT_KEY_LEFT, "l", "LEFT", "Left") \
	KEY("Down", GT_KEY_DOWN, "w", "DOWN", "Down") \
	KEY("Right", GT_KEY_RIGHT, "g", "RGHT", "Right") \
	KEY("Ctrl", GT_KEY_CTRL, "c", "CTRL", "Ctrl") \
	KEY("Shift", GT_KEY_SHIFT, "f", "SHFT", "Shift") \
	KEY("Caps", GT_KEY_CAPS, "p", "CAPS", "CapsLock") \
	KEY("Hiragana", GT_KEY_HIRAGANA, "j", "HIRA", "") \
	KEY("No Convert", GT_KEY_NO_CONVERT, "n", "MUHE", "") \
	KEY("Convert", GT_KEY_CONVERT, "v", "HENK", "") \
	KEY("Kana Kanji", GT_KEY_KANA_KANJI, "k", "KANJ", "") \
	KEY("Katakana", GT_KEY_KATAKANA, "a", "KATA", "") \
	KEY("PF12", GT_KEY_PF12, "x", "PF12", "F12") \
	KEY("Alt", GT_KEY_ALT, "m", "ALT", "Alt") \
	KEY("PF1", GT_KEY_PF1, "!", "PF1", "F1") \
	KEY("PF2", GT_KEY_PF2, "!", "PF2", "F2") \
	KEY("PF3", GT_KEY_PF3, "!", "PF3", "F3") \
	KEY("PF4", GT_KEY_PF4, "!", "PF4", "F4") \
	KEY("PF5", GT_KEY_PF5, "!", "PF5", "F5") \
	KEY("PF6", GT_KEY_PF6, "!", "PF6", "F6") \
	KEY("PF7", GT_KEY_PF7, "!", "PF7", "F7") \
	KEY("PF8", GT_KEY_PF8, "!", "PF8", "F8") \
	KEY("PF9", GT_KEY_PF9, "!", "PF9", "F9") \
	KEY("PF10", GT_KEY_PF10, "!", "PF10", "F10") \
	KEY("PF11", GT_KEY_PF11, "!", "PF11", "F11") \
	KEY("Kanji Dictionary", GT_KEY_KANJI_DICTIONARY, "!", "JISH", "") \
	KEY("Delete Word", GT_KEY_DELETE_WORD, "!", "MSHO", "") \
	KEY("Add Word", GT_KEY_ADD_WORD, "!", "TORO", "") \
	KEY("Previous", GT_KEY_PREVIOUS, "!", "PREV", "PageUp") \
	KEY("Next", GT_KEY_NEXT, "!", "NEXT", "PageDown") \
	KEY("Half Full", GT_KEY_HALF_FULL, "!", "HANZ", "") \
	KEY("Cancel", GT_KEY_CANCEL, "!", "CANC", "End") \
	KEY("Execute", GT_KEY_EXECUTE, "!", "EXEC", "") \
	KEY("PF13", GT_KEY_PF13, "!", "PF13", "F13") \
	KEY("PF14", GT_KEY_PF14, "!", "PF14", "F14") \
	KEY("PF15", GT_KEY_PF15, "!", "PF15", "F15") \
	KEY("PF16", GT_KEY_PF16, "!", "PF16", "F16") \
	KEY("PF17", GT_KEY_PF17, "!", "PF17", "F17") \
	KEY("PF18", GT_KEY_PF18, "!", "PF18", "F18") \
	KEY("PF19", GT_KEY_PF19, "!", "PF19", "F19") \
	KEY("PF20", GT_KEY_PF20, "!", "PF20", "F20") \
	KEY("Break", GT_KEY_BREAK, "!", "BRK", "Pause") \
	KEY("Copy", GT_KEY_COPY, "!", "COPY", "PrintScreen")

#define KEY_COUNT 117

#endif
