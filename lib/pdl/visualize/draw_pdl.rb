require 'erb'
require './lib/pdl'

class DrawPdl

  def initialize proto
    @proto = proto
  end

end

filename = 'erb/drawing.rhtml'
erb = ERB.new(File.read(filename))
erb.filename = filename

DrawPdl = erb.def_class(DrawPdl, 'render()')

class InformationInstruction 
  def to_html
    "#{@content}"
  end
end

class TakeInstruction 
  def to_html
    "Take #{@quantity} of <i>#{@object_type}</i> and refer to it as #{@var}."
  end
end

class ReleaseInstruction 
  def to_html
    "Put #{@expr} away."
  end
end

class ProduceInstruction 
  def to_html
    "Store #{@object_type_name} #{@location}."
  end
end

class AssignInstruction 
  def to_html
    "#{@var} := #{@value}"
  end
end

class StepInstruction
  def to_html
    str = ""
    @parts.each do |p|
      case p.keys.first
        when :description
          str += "#{p[:description]}"
        when :note
          str += "<span class='note'>Note: #{p[:note]}</span>"
        when :getdata
          str += "<span class='getdata'>Input: <i>#{p[:getdata][:var]}</i>: #{p[:getdata][:description]}.</span>"
      end
    end
    return str
  end
end

class IfInstruction
  def to_html
    "<span class='note'>#{@condition}</span>"
  end
end

class WhileInstruction
  def to_html
    "<span class='note'>#{@condition}</span>"
  end
end

class GotoInstruction
  def to_html
    "#{@destination}"
  end
end

class LogInstruction
  def to_html
    "<i>#{@type}</i>: #{data}"
  end
end

proto = Protocol.new 
proto.open ARGV.shift
proto.parse

print DrawPdl.new(proto).render()
