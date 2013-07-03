require 'rexml/document'
include REXML

class Protocol

  attr_reader :program, :include_stack, :args
  attr_writer :file

  def initialize
    @program = []
    @args = []
    @include_stack = []; # has the form [ { xmldoc: x , ce: c }, ... ]
    @control_stack = [];
    @log_path = ""
  end

  def push i
    @program.push i
  end
    
  def push_arg a
    @args.push a
  end

  def children_as_text e
    e.elements.collect { |p| { p.name.to_sym => p.text } }.reduce :merge
  end

  def show
    pc = 0
    @program.each do |i|
      puts pc.to_s + ": " + i.to_s
      pc += 1
    end
  end

  def info
    str = ""
    @program.each do |i|
      str = str + i.content if i.name == 'information'
    end
    str
  end

  def open path

    begin
      file = File.new(path)
    rescue 
      puts "Could not find file '#{path}'."
      return false
    end
    
    parse_xml file

  end

  def parse_xml file

    begin
      xml = Document.new(file)
    rescue REXML::ParseException => ex
      puts "A parse error was encountered."
      puts ex.to_s #.match(/Line:.*/)
      return false
    end

    @include_stack.push( { xmldoc: xml, ce: xml.root.elements.first } )
    return true

  end

  def increment el

    e = el

    if !e.next_element 
      x = e.parent.next_element
      while e && !x
        e = e.parent
        if e
          x = e.next_element
        else
          x = nil # isn't x just nil anyway at this point?
        end
      end
      e = x
    else
      e = e.next_element
    end

    return e

  end

  def parse

    while @include_stack.any?

      e = @include_stack.last[:ce]

      while e

        case e.name

          when 'information'
            push InformationInstruction.new e.text  
            e = increment e

          when 'step'
            parts = []
            e.elements.each do |tag|
              case tag.name
                when 'getdata'
                  parts.push({:getdata =>  (children_as_text tag)} )
		else 
		  parts.push({tag.name.to_sym => tag.text})
              end
            end
            push StepInstruction.new parts
            e = increment e

          when 'assign'
            c = children_as_text e
            push AssignInstruction.new c[:var], c[:value]
            e = increment e

          when 'argument'
            c = children_as_text e
            push_arg ArgumentInstruction.new c[:var], c[:description]
            e = increment e

          when 'include'
            args = []
            file = ""
            rsym = nil
            rval = ""
            e.elements.each do |tag|
              case tag.name
                when 'path'
                  file = tag.text
                  @include_stack.last[:ce] = e.next_element
                  self.open tag.text
                  e = @include_stack.last[:ce]
                when 'setarg'
                  args.push( children_as_text tag )
                when 'return'
                  r = children_as_text tag
                  rsym = r[:var].to_sym
                  rval = r[:value]
              end
              
            end

            push StartIncludeInstruction.new args, file
            @include_stack.last[:end_include] = EndIncludeInstruction.new rsym, rval

          when 'if'
            condition = e.elements.first
            thenpart = condition.next_element
            elsepart = thenpart.next_element

            @control_stack.push @program.length
            push IfInstruction.new condition.text

            et = REXML::Element.new           # push an end_then statement after the then part
            et.name = 'end_then'
            e.insert_after( thenpart, et )

            ee = REXML::Element.new           # push an end_else statement after the then part
            ee.name = 'end_else'
            e.insert_after( elsepart, ee )

            e = thenpart

          when 'then'
            program[@control_stack.last].mark_then @program.length
            e = e.elements.first

          when 'end_then'
            g = GotoInstruction.new
            program[@control_stack.last].mark_end_then @program.length  # tell if statement where its end_then
            push g
            e = increment e

          when 'else'
            program[@control_stack.last].mark_else @program.length
            e = e.elements.first

          when 'end_else'
            # tell the end_then goto statement where to go
            program[program[@control_stack.last].end_then_pc].mark_destination @program.length
            @control_stack.pop
            e = increment e

          when 'while'
            condition = e.elements.first  # get condition and do
            do_ = condition.next_element

            @control_stack.push @program.length                           # save location of while
            push WhileInstruction.new condition.text, @program.length + 1 # push new while instruction

            ew = REXML::Element.new     # add an end_while statement to the xmldoc
            ew.name = 'end_while'
            e.add_element ew

            e = do_

          when 'do'
            e = e.elements.first

          when 'end_while'
            g = GotoInstruction.new
            g.mark_destination @control_stack.last
            push g
            program[@control_stack.last].mark_false @program.length
            @control_stack.pop
            e = increment e

          when 'take'
            c = children_as_text e
            push(TakeInstruction.new c[:object], c[:quantity].to_i, c[:var])
            e = increment e

          when 'release'
            c = children_as_text e
            push ReleaseInstruction.new c[:var]
            e = increment e

          when 'produce'
            c = children_as_text e
            push ProduceInstruction.new c[:object], c[:location]
            e = increment e

          when 'log'
            c = children_as_text e
            push LogInstruction.new c[:type], c[:data], 'log_file'
            e = increment e

          else
            e = increment e

        end

      end

      if @include_stack.length > 1 
        push @include_stack.last[:end_include]
      end
      @include_stack.pop
 
    end

    return true

  end

end
