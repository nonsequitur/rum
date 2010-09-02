require 'rum'

Rum.layout.modifier 'caps'
'caps'.do '(cmd (tab))'
'caps shift'.do { active_window.close }

require 'rum/apps'
'caps h'.do { puts 'Hello from Rum!' }
'caps p'.do { Photoshop.activate }
'caps down'.do(Photoshop) { Photoshop.next_blend_mode }
'caps b'.do { Chrome.activate_and_focus_address_bar }
'caps s'.do { Emacs.eval '(slime-repl)'; Emacs.activate }
'caps c'.do { Clipboard.append }
'ctrl shift h'.do { type 'hi' }
# Caveat: Some hotkey actions are not yet available on the Mac.

Rum.start
