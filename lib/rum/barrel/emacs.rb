require 'rum/barrel/emacs_client'

class << Emacs
  attr_accessor :client, :eval_in_user_buffer

  Emacs.client = EmacsClient.new

  def eval(elisp)
    # MacRuby hack
    # @client.eval fails
    elisp = "(with-current-buffer (window-buffer) #{elisp})" if @eval_in_user_buffer
    Emacs.client.eval(elisp)
  end

  def funcall(*args)
    eval("(#{args.join(' ')})")
  end

  Quoting = [["\n", '\n'],
             ['"', '\\"']]

  def quote(str)
    str.gsub!('\\', '\\\\\\\\')
    Quoting.each { |from, to|  str.gsub!(from, to) }
    '"' << str << '"'
  end

  def unquote(str)
    Quoting.reverse.each { |from, to| str.gsub!(to, from) }
    str.gsub('\\\\', '\\').chomp[1..-2]
  end

  def find_file(path, line)
    line = if line.is_a? Fixnum
             "(goto-line #{line})"
           end
    eval("(progn (find-file \"#{path}\")#{line})")
  end

  def open_file(path, line=nil)
    Emacs.activate
    Emacs.find_file(path, line)
  end
end
