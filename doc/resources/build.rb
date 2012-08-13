require 'haml'

Encoding.default_external = Encoding::UTF_8

class Doc
  module Pygmentize
    Bin = if RUBY_PLATFORM =~ /mswin|mingw/ and ENV['USER'] == 'nonsequitur'
            python_dir = File.expand_path('~/vendor/Python32')
            "#{python_dir}/python.exe #{python_dir}/scripts/pygmentize"
          else
            'pygmentize'
          end
    Cmd = "#{Bin} -l ruby -f html"

    def self.file file
      fix_pygments_output(`#{Cmd} #{file}`)
    end

    def self.string str
      IO.popen(Cmd, 'w+') do |pygmentize|
        pygmentize.write str
        pygmentize.close_write
        fix_pygments_output(pygmentize.read)
      end
    end

    def self.fix_pygments_output str
      # Don't highlight 'require'
      str.gsub('<span class="nb">require</span>', 'require')
    end

    class Snippets
      def initialize
        @snippets = []
        @highlighted = []
      end

      def add str
        @snippets << str
        result = ''
        @highlighted << result
        result
      end

      def pygmentize!
        highlighted = Pygmentize.string(@snippets.join("\n")).lines.to_a
        highlighted.first.sub! /<div.*?pre>/, ''
        @snippets.each_with_index do |snippet, i|
          length = snippet.lines.to_a.length
          str  = '<pre class="highlight">'
          str << highlighted.slice!(0, length).join.chomp
          str << '</pre>'
          @highlighted[i].replace str
        end
      end
    end
  end

  class Code
    def initialize(file)
      @lines = File.read(file).split /\n/
    end

    def render
      parse
      to_html
    end

    def parse
      @result = []
      @last_type = nil
      @lines.each { |line| compose_doc(*classify_and_extract(line)) }
      @result
    end

    def classify_and_extract line
      case line
      when /^#?\s*$/      then [:empty,   nil]
      when /^####\s+(.*)/ then [:chapter, $1.rstrip]
      when /^###\s+(.*)/  then [:h2,      $1.rstrip]
      when /^##\s+(.*)/   then [:h3,      $1.rstrip]
      when /^#\s*(.*)/    then [:text,    $1.rstrip]
      else [:code, line]
      end
    end

    EmptyAllowed = { code: true, text: true }

    def compose_doc type, line
      if type == :empty
        @result.last << '' if EmptyAllowed[@last_type]
      elsif type == @last_type
        @result.last << line
      else
        @result << [type, line]
        @last_type = type
      end
    end

    class TableOfContents
      Heading = Struct.new(:text, :anchor_name)

      def initialize
        @headings = []
      end

      def add_heading heading
        chapter_number = @headings.count + 1
        @headings << Heading.new(heading, "chapter_#{chapter_number}")
      end

      def heading_html
        heading = @headings.last
        "<a name=\"#{heading.anchor_name}\"><h1>#{heading.text}</h1></a>"
      end

      def heading_list_items
        @headings.map do |heading|
          "<li><a href=\"##{heading.anchor_name}\">#{heading.text}</a></li>"
        end.join
      end

      def to_html
        html  = "<div id=\"table_of_contents\"><h1>Chapters</h1>"
        html << "<ul>"
        html << heading_list_items
        html << "</ul>"
        html << "</div>"
      end
    end

    ChapterEnd = "</div>\n"
    ChapterBeginning = "<div class=\"chapter\">\n"

    def to_html
      snippets = Pygmentize::Snippets.new
      table_of_contents = TableOfContents.new

      sections = @result.map do |type, *lines|
        case type
        when :chapter
          table_of_contents.add_heading lines.first
          chapter  = ChapterEnd.dup
          chapter << ChapterBeginning
          chapter << table_of_contents.heading_html << "\n"
        when :h2
          "<h2>#{lines.first}</h2>"
        when :h3
          "<h3>#{lines.first}</h3>"
        when :text
          "<p>#{join_text(lines)}</p>"
        when :code
          snippets.add(lines.join("\n").rstrip)
        end
      end

      sections.first.sub! ChapterEnd, ''
      sections << ChapterEnd
      sections.unshift table_of_contents.to_html

      snippets.pygmentize!
      sections.join("\n")
    end

    def join_text(lines)
      paragraphs = []
      paragraphs << lines.first.dup
      lines.each_cons(2) do |a, b|
        if (a.empty? or b.empty? or
            a.chars.to_a.last =~ /[.:!?)>]/ or a.length < 8)
          paragraphs << b
        else
          paragraphs.last << ' ' <<  b
        end
      end
      paragraphs.pop while paragraphs.last.empty?
      paragraphs.join('<br />')
    end
  end

  def initialize(index, intro, basic, example, reference, args)
    @dir = args[:dir] || ''
    @output    = File.join(@dir, args[:output])
    @index     = File.join(@dir, index)
    @intro     = File.join(@dir, intro)
    @basic     = File.join(@dir, basic)
    @example   = File.join(@dir, example)
    @reference = File.join(@dir, reference)
  end

  def current_version
    gemspec = eval(IO.read('rum.gemspec'))
    gemspec.version
  end

  def intro
    Pygmentize.file @intro
  end

  def inf_ruby_setup
    <<EOF
(add-to-list 'inf-ruby-implementations
  '("rum-client" . "rum-client -i --inf-ruby-mode")
(defun rum-client ()
  (interactive)
  (inf-ruby "rum-client")))
EOF
  end

  def basic
    Pygmentize.file(@basic)
  end

  def example
    Pygmentize.file @example
  end

  def reference
    Doc::Code.new(@reference).render
  end

  def render
    doc = File.read(@index)
    # Ugly is needed for Pygments-formatted code
    haml = Haml::Engine.new(doc, ugly: true)
    @doc = haml.render(self)
  end

  def save
    File.open(@output, 'wb') { |f| f.write @doc }
  end

  def build
    render
    save
  end
end
